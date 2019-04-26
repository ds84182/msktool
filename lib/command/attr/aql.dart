library msktool.command.attr.aql;

import 'aql_runtime.dart' show AqlContext;
export 'aql_runtime.dart' show AqlContext;
import 'package:msk_attr/msk_attr.dart';
import 'package:petitparser/petitparser.dart' as pp;

Iterable<T> _castUntyped<T>(List untyped) => untyped.map((v) => v as T);

// Since AQL compiles synchronously this is safe to do.
AqlContext _currentContext;

final whitespace = pp.whitespace().plus();
final optWhitespace = pp.whitespace().star();

//pp.Parser makeStringList(Iterable<String> words) =>
//    words.map(pp.string).reduce((a, b) => a & whitespace & b);

final from = pp.string("FROM") & whitespace & expression;

final query = from;

final expression = pp.undefined();

final separator = optWhitespace & pp.char(',') & optWhitespace;

final parenQuery =
    (pp.char('(') & optWhitespace & query & optWhitespace & pp.char(')'))
        .pick(2);
final parenExpr =
    (pp.char('(') & optWhitespace & expression & optWhitespace & pp.char(')'))
        .pick(2);

final identifier = (pp.word() | pp.char(r'$')).plus().flatten();

// block:* vs. block:pizzaoven

// So we can do something like:
// FROM mapnode:(FROM map:* SELECT MapNodeList)
// Since MapNodeList is an array of CollectionKey we have to turn it into a
// RefSpec using :.
// Solution: `:` should become an operator, `*` should become a keyword.
// `*` is only allowed on the rhs of the "refspec" `:` operator.

final type = pp.undefined();

// a
// a: type
final lambdaParam =
    (identifier & (pp.char(':') & optWhitespace & type).optional())
        .map((List args) => new LambdaParameter(
              name: args.first as String,
              type: args.last as ExpressionType,
            ));

// a, b ->
final lambdaBindParams =
    (lambdaParam.separatedBy(separator, includeSeparators: false) &
            optWhitespace &
            pp.string("->"))
        .pick(0);

// { <expression> }
// { a, b -> <expression> }
final lambda = (pp.char('{') &
    optWhitespace &
    lambdaBindParams.optional() &
    optWhitespace &
    expression &
    optWhitespace &
    pp.char('}')).permute(const [2, 4]).map<LambdaNode>(
  (List args) {
    final params =
        args.first as List<LambdaParameter> ?? const <LambdaParameter>[];
    final body = args.last as ExpressionNode;
    return new LambdaNode(_currentContext, params, body);
  },
);

// list { expr, expr, expr, ... }
// TODO: list of Type { expr, expr, expr, ... }
final listConstructor = (pp.string("list") &
        optWhitespace &
        pp.char('{') &
        optWhitespace &
        expression
            .separatedBy(
          separator,
          includeSeparators: false,
          optionalSeparatorAtEnd: true,
        )
            .optional(const []) &
        optWhitespace &
        pp.char('}'))
    .pick(4)
    .cast<List>()
    .map<ListNode>((List expressions) => new ListNode(
          _currentContext,
          _castUntyped<ExpressionNode>(expressions).toList(growable: false),
        ));

final exprLeaves = parenQuery |
    parenExpr |
    listConstructor |
    pp.digit().plus().flatten().map((String number) =>
        new IntConstantNode(_currentContext, int.parse(number))) |
    pp.string("null").map((_) => new NullNode(_currentContext)) |
    (identifier.map((String ident) =>
        new UnresolvedIdentifierNode(_currentContext, ident))) |
    lambda;

bool _inited = false;

void _init() {
  if (_inited) return;
  _inited = true;

  type.set(
    (identifier &
        (optWhitespace &
                pp.char('<') &
                type.separatedBy(optWhitespace & pp.char(',') & optWhitespace,
                    includeSeparators: false) &
                optWhitespace &
                pp.char('>'))
            .pick(2)
            .optional()).map(
      (List l) {
        final typeName = l.first as String;
        final typeParams = l.last as List;

        if (typeName == "List") {
          // Expect generic parameters
          if (typeParams == null)
            throw "Expected type parameters for type $typeName";

          if (typeParams.length != 1) {
            throw "Unexpected number of type parameters for type $typeName (got ${typeParams.length})";
          }

          final param = typeParams.single as ExpressionType;
          switch (param) {
            case ExpressionType.collectionKey:
              return ExpressionType.collectionKeys;
            default:
              return new ListExpressionType(param);
          }
        } else {
          // Expect no generic parameters
          if (typeParams != null)
            throw "Unexpected type parameters for type $typeName";

          switch (typeName) {
            case "Key":
              return ExpressionType.key;
            case "ClassKey":
              return ExpressionType.classKey;
            case "CollectionKey":
              return ExpressionType.collectionKey;
            case "RefSpec":
              return ExpressionType.refSpec;
            default:
              return ExpressionType.unknown;
          }
        }
      },
    ),
  );

  final builder = new pp.ExpressionBuilder();

  builder.group()..primitive(exprLeaves);
  builder.group()
    ..postfix(optWhitespace & pp.string(":*"),
        (prefix, _) => new RefSpecSpreadNode(_currentContext, prefix))
    ..left(
        optWhitespace & pp.char(':') & optWhitespace,
        (lhs, _, rhs) =>
            RefSpecNode.createFromParser(_currentContext, lhs, rhs));
  builder.group()
    ..postfix(
        (optWhitespace & pp.char('.') & optWhitespace & identifier).pick(3),
        (lhs, identifier) =>
            new UnresolvedIndexNode(_currentContext, lhs, identifier))
    ..postfix(
        (optWhitespace &
                pp.char('[') &
                optWhitespace &
                expression &
                optWhitespace &
                pp.char(']'))
            .pick(3),
        (lhs, index) =>
            new UnresolvedDynamicIndexNode(_currentContext, lhs, index));
  builder.group()
    ..postfix(whitespace & pp.string("children"),
        (a, _) => new ChildrenNode(_currentContext, a))
    ..left(whitespace & pp.string("select") & whitespace,
        (a, _, b) => new SelectNode(_currentContext, a, b))
    ..left(whitespace & pp.string("where") & whitespace,
        (a, _, b) => new WhereNode(_currentContext, a, b))
    ..left(whitespace & pp.string("sum") & whitespace,
        (a, _, b) => new SumNode(_currentContext, a, b))
    ..left(whitespace & pp.string("sort by") & whitespace,
        (a, _, b) => new SortByNode(_currentContext, a, b));
  builder.group()
    ..postfix(
        (whitespace &
                pp.string("is") &
                (whitespace & pp.string("not"))
                    .map((_) => true)
                    .optional(false) &
                whitespace &
                pp.string("empty"))
            .pick(2),
        (a, inverted) => new IsEmptyNode(_currentContext, a, inverted))
    ..left(
        (whitespace &
                pp.string("is") &
                (whitespace & pp.string("not"))
                    .map((_) => true)
                    .optional(false) &
                whitespace)
            .pick(2),
        (a, inverted, b) => new IsNode(_currentContext, a, b, inverted));

  expression.set(
    builder.build(),
  );
}

final pp.Parser aql = () {
  _init();
  return (query | expression).end();
}();

pp.Result parseAql(AqlContext context, String str) {
  _currentContext = context;
  final parser = aql.parse(str);
  _currentContext = null;
  return parser;
}

abstract class ExpressionType {
  const ExpressionType();

  String get name;

  ExpressionType get superType => unknown;

  bool get isBottom => identical(this, bottom);

  bool isSubtypeOf(ExpressionType superType) {
    if (isBottom) {
      // Every type is a super type to bottom
      return true;
    }

    if (identical(superType, unknown)) {
      // Every type is a sub type of unknown
      return true;
    }

    ExpressionType subType = this;
    while (subType != null) {
      if (subType.isTypeIdentical(superType)) {
        return true;
      }
      subType = subType.superType;
    }
    return false;
  }

  ExpressionType commonTypeOf(ExpressionType other) {
    // [int, String]; [int, Unknown] -> Unknown
    // [num, int]; [num, num] -> num
    // [String, int]; [String, num]; [String, Unknown] -> Unknown

    while (other != null) {
      if (isSubtypeOf(other)) {
        return other;
      }

      other = other.superType;
    }

    throw new UnsupportedError("Bad type hierarchy");
  }

  // In Dart terms, int is more specific than num, since int's super type is num
  // An int is also assignable to a num, so we can use [isAssignableTo].
  bool isMoreSpecificThan(ExpressionType other) => isAssignableTo(other);

  @override
  String toString() => name;

  bool isAssignableTo(ExpressionType other) => isSubtypeOf(other);

  bool isTypeIdentical(ExpressionType other) => identical(this, other);

  T resolveConstant<T>(Type type, {Object key}) => null;

  ListExpressionType wrapList() => new ListExpressionType(this);

  static const unknown = const UnknownExpressionType();
  static const bottom = const DefaultExpressionType("Bottom");

  static const key = const DefaultExpressionType("Key");
  static const classKey =
      const DefaultExpressionType("ClassKey", superType: key);
  static const collectionKey =
      const DefaultExpressionType("CollectionKey", superType: key);
  static const boolType = const DefaultExpressionType("bool");
  static const intType = const DefaultExpressionType("int");
  static const interestScore = const DefaultExpressionType("InterestScore");
  // TODO: Lambda with type params
  static const lambda = const DefaultExpressionType("Lambda");

  static const refSpec = const RefSpecExpressionType();

  static const list = const ListExpressionType(unknown);
  static const collectionKeys = const ListExpressionType(collectionKey);
  static const refSpecs = const ListExpressionType(refSpec);
}

class UnknownExpressionType extends ExpressionType {
  @override
  String get name => "dynamic";

  @override
  ExpressionType get superType => null;

  const UnknownExpressionType();
}

class DefaultExpressionType extends ExpressionType {
  @override
  final String name;

  @override
  final ExpressionType superType;

  const DefaultExpressionType(this.name,
      {this.superType: ExpressionType.unknown});

  @override
  bool isTypeIdentical(ExpressionType other) {
    return (other is DefaultExpressionType && other.name == name) ||
        super.isTypeIdentical(other);
  }
}

class ListExpressionType extends ExpressionType {
  final ExpressionType elementType;

  @override
  String get name => "List<${elementType.name}>";

  const ListExpressionType(this.elementType);

  @override
  bool isTypeIdentical(ExpressionType other) {
    return (other is ListExpressionType &&
            elementType.isAssignableTo(other.elementType)) ||
        super.isTypeIdentical(other);
  }

  @override
  String toString() => "List<$elementType>";
}

class RefSpecExpressionType extends ExpressionType {
  final ClassKey inferredClassKey;

  const RefSpecExpressionType([this.inferredClassKey]);

  @override
  String get name => "RefSpec";

  @override
  T resolveConstant<T>(Type type, {Object key}) {
    if (type == ClassKey) {
      return inferredClassKey as T;
    }
    return super.resolveConstant(type, key: key);
  }

  @override
  bool isAssignableTo(ExpressionType other) {
    return other is RefSpecExpressionType || super.isAssignableTo(other);
  }

  @override
  String toString() =>
      "RefSpec" +
      (inferredClassKey != null ? " (inferred as $inferredClassKey)" : "");

  RefSpecExpressionType withInferredClass(ClassKey classKey) =>
      new RefSpecExpressionType(classKey);
}

class LocalContext {
  final Map<String, ExpressionNode> scope;
  final List<LambdaParameter> implicitLambdaParams;

  const LocalContext({
    this.scope: const <String, ExpressionNode>{},
    this.implicitLambdaParams: const <LambdaParameter>[],
  });

  LocalContext _fork({
    Map<String, ExpressionNode> scope,
    List<LambdaParameter> implicitLambdaParams,
  }) =>
      new LocalContext(
        scope: scope ?? this.scope,
        implicitLambdaParams: implicitLambdaParams ?? this.implicitLambdaParams,
      );

  LocalContext withImplicitLambdaParameters(List<LambdaParameter> params) {
    return _fork(implicitLambdaParams: params);
  }

  LocalContext withScope(Map<String, ExpressionNode> scope) {
    return _fork(
      scope: new Map<String, ExpressionNode>.from(this.scope)..addAll(scope),
    );
  }
}

abstract class ExpressionNode {
  final AqlContext context;
  const ExpressionNode(this.context);

  ExpressionType get type;

  // If this node is already the correct type, returns this node.

  // If this node is of an unknown type (unresolved identifier),
  // take the type and use it for resolution, or return a type cast.

  // Otherwise, if this node has a definite type then an error is thrown.
  void propagateType(ExpressionType type);

  ExpressionNode resolve(LocalContext context);

  String compile();

  // TODO: Inspect all uses of resolveConstant, try lift constant resolution into type system
  // UPDATE: Some constant resolution has been lifted into the type system.
  T resolveConstant<T>(Type type) => this.type.resolveConstant(type);
}

class InvalidTypeException implements Exception {
  final String message;

  InvalidTypeException.single(ExpressionType expected, ExpressionType got,
      [String info])
      : message =
            "$expected expected, got $got" + (info != null ? " ($info)" : "");

  @override
  String toString() => message;
}

/// Asserts that the given node is assignable to the given type.
/// If not, an implicit conversion is searched for.
/// If there is an implicit conversion then the node is converted.
/// Otherwise an exception is thrown.
/// Returns the given node if assignable, or an implicitly converted node.
ExpressionNode typeAssert(ExpressionNode node, ExpressionType type,
    [String info]) {
  if (node.type.isAssignableTo(type)) {
    return node..propagateType(type);
  }

  if (node is UnresolvedIdentifierNode) {
    // TODO: When we have proper subtyping this can become a single assignable check to key
    if (type.isSubtypeOf(ExpressionType.key)) {
      return new AttributeKeyNode(node.context, node.identifier, type);
    }
  }

  try {
    if (type.isAssignableTo(ExpressionType.refSpecs) ||
        type.isAssignableTo(ExpressionType.list)) {
      // Try a ChildRefSpecs implicit conversion
      final asRefSpec = typeAssert(node, ExpressionType.refSpec);
      final classKey = asRefSpec.resolveConstant<ClassKey>(ClassKey);

      // Do we have a constant class key?
      if (classKey != null) {
        // Yep, does it have ChildRefSpecs?
        final field = classKey.lookupField(attrId("ChildRefSpecs"));

        if (field != null) {
          // Also yes!
          // Implicit conversion success!
          return new ChildRefSpecsNode(asRefSpec.context, asRefSpec);
        }
      }

      // Otherwise... implicit conversion failed
    }
  } on InvalidTypeException {} // Ignore

  // No implicit conversion found
  throw new InvalidTypeException.single(type, node.type, info);
}

abstract class ConcreteTypedNode implements ExpressionNode {
  @override
  void propagateType(ExpressionType type) {
    if (!this.type.isAssignableTo(type)) {
      throw new InvalidTypeException.single(
          type, this.type, "In concrete type check");
    }
  }
}

class NullNode extends ExpressionNode with ConcreteTypedNode {
  NullNode(AqlContext context) : super(context);

  @override
  String compile() => "null";

  @override
  ExpressionNode resolve(LocalContext context) => this;

  @override
  ExpressionType get type => ExpressionType.bottom;
}

class IntConstantNode extends ExpressionNode with ConcreteTypedNode {
  int value;

  IntConstantNode(AqlContext context, this.value) : super(context);

  @override
  String compile() => "$value";

  @override
  ExpressionNode resolve(LocalContext context) => this;

  @override
  ExpressionType get type => ExpressionType.intType;
}

class UnresolvedIdentifierNode extends ExpressionNode {
  final String identifier;

  UnresolvedIdentifierNode(AqlContext context, this.identifier)
      : super(context);

  @override
  void propagateType(ExpressionType type) {} // Nothing to do

  @override
  ExpressionNode resolve(LocalContext context) {
    if (context.scope.containsKey(identifier)) {
      return context.scope[identifier];
    }

    return this;
  }

  @override
  String compile() {
    throw "TODO throw real error, TODO tokens, unresolved identifier $identifier";
  }

  // Type is initially unknown, since we need to be implicitly converted.
  @override
  ExpressionType get type => ExpressionType.unknown;
}

class AttributeKeyNode extends ExpressionNode with ConcreteTypedNode {
  final String identifier;

  @override
  final ExpressionType type;

  AttributeKeyNode(AqlContext context, this.identifier, this.type)
      : super(context);

  @override
  ExpressionNode resolve(LocalContext context) => this;

  @override
  T resolveConstant<T>(Type constType) {
    if (constType == ClassKey ||
        constType == CollectionKey ||
        constType == Key) {
      if (type == ExpressionType.classKey) {
        return new ClassKey.byName(context.attrContext, identifier) as T;
      } else if (type == ExpressionType.collectionKey) {
        return new CollectionKey.byName(context.attrContext, identifier) as T;
      } else {
        return new Key.byName(context.attrContext, identifier) as T;
      }
    }
    return super.resolveConstant<T>(constType);
  }

  @override
  String compile() {
    final id = attrId(identifier);

    if (type == ExpressionType.classKey) {
      return "new ClassKey(attrContext, $id /* $identifier */)";
    } else if (type == ExpressionType.collectionKey) {
      return "new CollectionKey(attrContext, $id /* $identifier */)";
    } else {
      return "new Key(attrContext, $id /* $identifier */)";
    }
  }
}

class LambdaParameter {
  final String name;
  final ExpressionType type;
  const LambdaParameter({this.name: r'$', this.type});
}

class LambdaParameterNode extends ExpressionNode with ConcreteTypedNode {
  final LambdaParameter parameter;

  LambdaParameterNode(AqlContext context, this.parameter) : super(context);

  @override
  String compile() {
    return parameter.name;
  }

  @override
  ExpressionNode resolve(LocalContext context) => this;

  @override
  ExpressionType get type => parameter.type;
}

class LambdaNode extends ExpressionNode with ConcreteTypedNode {
  List<LambdaParameter> parameters;
  ExpressionNode body;

  LambdaNode(AqlContext context, List<LambdaParameter> parameters, this.body)
      : parameters = <LambdaParameter>[],
        super(context);

  @override
  String compile() {
    final p = parameters
        .map((param) => "${param.type.name} ${param.name} /* ${param.type} */")
        .join(", ");
    return "($p) => ${body.compile()}";
  }

  @override
  ExpressionNode resolve(LocalContext context) {
    if (parameters.isEmpty) {
      parameters = context.implicitLambdaParams;
    } else {
      // Try merge
      // TODO: Don't override types
      for (int i = 0; i < context.implicitLambdaParams.length; i++) {
        parameters[i] = new LambdaParameter(
          name: parameters[i].name,
          type: context.implicitLambdaParams[i].type,
        );
      }
    }

    context = context.withScope(
      new Map<String, ExpressionNode>.fromIterables(
        parameters.map((p) => p.name),
        parameters.map(
          (p) => new LambdaParameterNode(this.context, p),
        ),
      ),
    );

    body = body.resolve(context);

    return this;
  }

  @override
  ExpressionType get type => ExpressionType.lambda;
}

class ListNode extends ExpressionNode with ConcreteTypedNode {
  List<ExpressionNode> expressions;

  ListNode(AqlContext context, this.expressions) : super(context);

  @override
  String compile() {
    return "<${type.elementType.name}>[${expressions.map((node) => node.compile()).join(", ")}] /* $type */";
  }

  @override
  ExpressionNode resolve(LocalContext context) {
    for (int i = 0; i < expressions.length; i++) {
      expressions[i] = expressions[i].resolve(context);
    }

    // Try to determine list type
    ExpressionType type = ExpressionType.bottom;
    for (final expr in expressions) {
      type = expr.type.commonTypeOf(type);
    }
    if (type.isBottom) type = ExpressionType.unknown;

    this.type = type.wrapList();

    return this;
  }

  ListExpressionType type = ExpressionType.list;
}

// TODO: *spread operator
// If a ListNode contains a spread operator, the expression is spread into the
// list.
// Otherwise, a spread operator is the equivalent of:
// iterable.expand((l) => l is Iterable ? l : [l])
// Except where the Iterable check is optimized out if known not to be an
// Iterable.

class IndeterminateRefSpecNode extends ExpressionNode with ConcreteTypedNode {
  ExpressionNode classKey, collectionKey;

  IndeterminateRefSpecNode(
      AqlContext context, this.classKey, this.collectionKey)
      : super(context);

  @override
  String compile() {
    throw "Not supposed to compile indeterminate ref spec";
  }

  @override
  ExpressionNode resolve(LocalContext context) {
    classKey = classKey.resolve(context);
    classKey = typeAssert(classKey, ExpressionType.classKey);

    collectionKey = collectionKey.resolve(context);
    if (collectionKey is UnresolvedIdentifierNode) {
      // Go ahead and resolve the identifier to a CollectionKey constant
      collectionKey = typeAssert(collectionKey, ExpressionType.collectionKey);
    }

    if (collectionKey.type.isAssignableTo(ExpressionType.collectionKey)) {
      // Key type OK, no surprises
      return new RefSpecNode(this.context, classKey, collectionKey);
    } else if (collectionKey.type
        .isAssignableTo(ExpressionType.collectionKeys)) {
      // Multiple collection keys
      return new RefSpecsNode(this.context, classKey, collectionKey);
    } else {
      throw "TODO real error, ambiguous type for refspec collection "
          "(wanted ${ExpressionType.collectionKey} or "
          "${ExpressionType.collectionKeys}, got ${collectionKey.type})";
    }
  }

  @override
  ExpressionType get type => ExpressionType.unknown;
}

class RefSpecNode extends ExpressionNode with ConcreteTypedNode {
  ExpressionNode classKey, collectionKey;

  RefSpecNode(AqlContext context, this.classKey, this.collectionKey)
      : super(context);

  static ExpressionNode createFromParser(AqlContext context,
      ExpressionNode classKey, ExpressionNode collectionKey) {
    return new IndeterminateRefSpecNode(context, classKey, collectionKey);
  }

  @override
  ExpressionNode resolve(LocalContext context) {
    classKey = classKey.resolve(context);
    classKey = typeAssert(classKey, ExpressionType.classKey);

    collectionKey = collectionKey.resolve(context);
    collectionKey = typeAssert(collectionKey, ExpressionType.collectionKey);

    return this;
  }

  @override
  T resolveConstant<T>(Type constType) {
    if (constType == ClassKey) {
      return classKey.resolveConstant<T>(ClassKey);
    } else if (constType == CollectionKey) {
      return collectionKey.resolveConstant<T>(CollectionKey);
    } else if (constType == RefSpec) {
      final resolvedClassKey = resolveConstant<ClassKey>(ClassKey);
      if (resolvedClassKey == null) return null;
      final resolvedCollectionKey =
          resolveConstant<CollectionKey>(CollectionKey);
      if (resolvedCollectionKey == null) return null;
      return resolvedClassKey.withCollection(resolvedCollectionKey) as T;
    }
    return super.resolveConstant<T>(constType);
  }

  @override
  ExpressionType get type => ExpressionType.refSpec
      .withInferredClass(classKey.resolveConstant<ClassKey>(ClassKey));

  @override
  String compile() {
    return "${classKey.compile()}.withCollection(${collectionKey.compile()})";
  }
}

class RefSpecsNode extends ExpressionNode with ConcreteTypedNode {
  ExpressionNode classKey, collectionKeys;

  RefSpecsNode(AqlContext context, this.classKey, this.collectionKeys)
      : super(context);

  @override
  ExpressionNode resolve(LocalContext context) {
    classKey = classKey.resolve(context);
    classKey = typeAssert(classKey, ExpressionType.classKey);

    collectionKeys = collectionKeys.resolve(context);
    collectionKeys = typeAssert(collectionKeys, ExpressionType.collectionKeys);

    return this;
  }

  @override
  T resolveConstant<T>(Type constType) {
    if (constType == ClassKey) {
      return classKey.resolveConstant<T>(ClassKey);
    }
    return super.resolveConstant<T>(constType);
  }

  @override
  ExpressionType get type => ExpressionType.refSpec
      .withInferredClass(classKey.resolveConstant<ClassKey>(ClassKey))
      .wrapList();

  @override
  String compile() {
    return "context.makeRefSpecs(${classKey.compile()}, ${collectionKeys.compile()}) /* $type */";
  }
}

class ChildRefSpecsNode extends ExpressionNode with ConcreteTypedNode {
  ExpressionNode refSpec;

  ChildRefSpecsNode(AqlContext context, this.refSpec) : super(context);

  // ChildRefSpecs can contain mixed content, so we can't resolve a
  // ClassKey for it.

  @override
  ExpressionNode resolve(LocalContext context) {
    refSpec = refSpec.resolve(context);
    refSpec = typeAssert(refSpec, ExpressionType.refSpec);

    return this;
  }

  // Can't infer class key either
  @override
  ExpressionType get type => ExpressionType.refSpecs;

  @override
  String compile() {
    return "context.makeChildRefSpecs(${refSpec.compile()})";
  }
}

// Inheritance children (not tree children)
class ChildrenNode extends ExpressionNode with ConcreteTypedNode {
  ExpressionNode refSpec;

  ChildrenNode(AqlContext context, this.refSpec) : super(context);

  @override
  ExpressionNode resolve(LocalContext context) {
    refSpec = refSpec.resolve(context);
    refSpec = typeAssert(refSpec, ExpressionType.refSpec);
    return this;
  }

  @override
  ExpressionType get type => refSpec.type.wrapList();

  @override
  String compile() {
    return "context.childrenOf(${refSpec.compile()})";
  }
}

class RefSpecSpreadNode extends ExpressionNode with ConcreteTypedNode {
  ExpressionNode classKey;

  RefSpecSpreadNode(AqlContext context, this.classKey) : super(context);

  @override
  ExpressionNode resolve(LocalContext context) {
    classKey = classKey.resolve(context);
    classKey = typeAssert(classKey, ExpressionType.classKey);

    return this;
  }

  @override
  T resolveConstant<T>(Type constType) {
    if (constType == ClassKey) {
      return classKey.resolveConstant<T>(ClassKey);
    }
    return super.resolveConstant<T>(constType);
  }

  @override
  ExpressionType get type => ExpressionType.refSpec
      .withInferredClass(classKey.resolveConstant<ClassKey>(ClassKey))
      .wrapList();

  @override
  String compile() {
    return "context.makeRefSpecSpread(${classKey.compile()})";
  }
}

class UnresolvedIndexNode extends ExpressionNode with ConcreteTypedNode {
  ExpressionNode expression;
  String index;

  UnresolvedIndexNode(AqlContext context, this.expression, this.index)
      : super(context);

  @override
  String compile() {
    throw "Unresolved index `$index` for type `${expression.type}`";
  }

  @override
  ExpressionNode resolve(LocalContext context) {
    expression = expression.resolve(context);

    if (expression.type.isAssignableTo(ExpressionType.refSpec) ||
        expression.type.isAssignableTo(ExpressionType.refSpecs)) {
      return new CollectionIndexNode(this.context, expression, index)
          .resolve(context);
    } else if (expression.type.isAssignableTo(ExpressionType.interestScore)) {
      if (index == "score") {
        return new InterestScoreGetScoreNode(this.context, expression)
            .resolve(context);
      }
    }

    return this;
  }

  @override
  ExpressionType get type => ExpressionType.unknown;
}

class UnresolvedDynamicIndexNode extends ExpressionNode with ConcreteTypedNode {
  ExpressionNode expression;
  ExpressionNode index;

  UnresolvedDynamicIndexNode(AqlContext context, this.expression, this.index)
      : super(context);

  @override
  String compile() {
    throw "Unresolved dynamic index for type `${expression.type}`";
  }

  @override
  ExpressionNode resolve(LocalContext context) {
    expression = expression.resolve(context);
    index = index.resolve(context);

    if (expression.type is ListExpressionType) {
      return new ListIndexNode(this.context, expression, index)
          .resolve(context);
    }

    return this;
  }

  @override
  ExpressionType get type => ExpressionType.unknown;
}

class CollectionIndexNode extends ExpressionNode with ConcreteTypedNode {
  ExpressionNode refSpec;
  String index;
  bool refSpecList = false;

  CollectionIndexNode(AqlContext context, this.refSpec, this.index)
      : super(context);

  // Tries to deduce the type of this node from the field if the class is known
  void tryDeduceType() {
    final classKey = refSpec.resolveConstant<ClassKey>(ClassKey);

    if (classKey != null) {
      // So we try to figure out what we'd return so we can have a concrete type
      final field = classKey.lookupField(attrId(index));

      ExpressionType typeFromField = ExpressionType.unknown;

      if (field.type == Attrib.collectionKey) {
        typeFromField = ExpressionType.collectionKey;
      } else if (field.type == Attrib.refSpec) {
        typeFromField = ExpressionType.refSpec;
      } else if (field.type == MySims.interestScore) {
        typeFromField = ExpressionType.interestScore;
      }

      if (field.flags.contains(AttrFlag.array) ||
          field.flags.contains(AttrFlag.fixedArray)) {
        typeFromField = new ListExpressionType(typeFromField);
      }

      if (refSpecList) {
        typeFromField = new ListExpressionType(typeFromField);
      }

      this.type = typeFromField;
    } else {
      print(
          "Warning, could not get compile time RefSpec info for collection index");
    }
  }

  @override
  ExpressionNode resolve(LocalContext context) {
    refSpec = refSpec.resolve(context);

    if (refSpec.type.isAssignableTo(ExpressionType.refSpec)) {
      refSpec = typeAssert(refSpec, ExpressionType.refSpec);
    } else if (refSpec.type.isAssignableTo(ExpressionType.refSpecs)) {
      refSpec = typeAssert(refSpec, ExpressionType.refSpecs);
      refSpecList = true;
    } else {
      throw "TODO real error, ambiguous type for refspec index "
          "(wanted ${ExpressionType.refSpec} or "
          "${ExpressionType.refSpecs}, got ${refSpec.type})";
    }

    tryDeduceType();

    return this;
  }

  @override
  ExpressionType type = ExpressionType.unknown;

  @override
  String compile() {
    return "context.readField${refSpecList ? 's' : ''}<${type.name}>"
        "(${refSpec.compile()}, ${attrId(index)} /* $index */) /* $type */";
  }
}

class InterestScoreGetScoreNode extends ExpressionNode with ConcreteTypedNode {
  ExpressionNode interestScore;

  InterestScoreGetScoreNode(AqlContext context, this.interestScore)
      : super(context);

  @override
  ExpressionNode resolve(LocalContext context) {
    interestScore = interestScore.resolve(context);
    interestScore = typeAssert(interestScore, ExpressionType.interestScore);
    return this;
  }

  @override
  String compile() {
    return "${interestScore.compile()}.score";
  }

  @override
  ExpressionType get type => ExpressionType.intType;
}

class ListIndexNode extends ExpressionNode with ConcreteTypedNode {
  ExpressionNode list, index;

  ListIndexNode(AqlContext context, this.list, this.index) : super(context);

  @override
  ExpressionNode resolve(LocalContext context) {
    list = list.resolve(context);
    list = typeAssert(list, ExpressionType.list);

    index = index.resolve(context);
    index = typeAssert(index, ExpressionType.intType);

    this.type = (list.type as ListExpressionType).elementType;

    return this;
  }

  @override
  String compile() {
    return "${list.compile()}[${index.compile()}]";
  }

  @override
  ExpressionType type = ExpressionType.unknown;
}

class IsNode extends ExpressionNode with ConcreteTypedNode {
  ExpressionNode lhs, rhs;
  bool inverted;

  IsNode(AqlContext context, this.lhs, this.rhs, this.inverted)
      : super(context);

  @override
  String compile() {
    return "(${lhs.compile()}) ${inverted ? '!' : '='}= (${rhs.compile()})";
  }

  @override
  ExpressionNode resolve(LocalContext context) {
    lhs = lhs.resolve(context);
    rhs = rhs.resolve(context);

    return this;
  }

  @override
  ExpressionType get type => ExpressionType.boolType;
}

class IsEmptyNode extends ExpressionNode with ConcreteTypedNode {
  bool inverted;
  ExpressionNode lhs;

  IsEmptyNode(AqlContext context, this.lhs, this.inverted) : super(context);

  @override
  String compile() {
    return "(${lhs.compile()})?.is${inverted ? "Not" : ""}Empty ?? false";
  }

  @override
  ExpressionNode resolve(LocalContext context) {
    lhs = lhs.resolve(context);
    return this;
  }

  @override
  ExpressionType get type => ExpressionType.boolType;
}

class SelectNode extends ExpressionNode with ConcreteTypedNode {
  ExpressionNode expression;
  LambdaNode lambda;

  SelectNode(AqlContext context, this.expression, this.lambda) : super(context);

  @override
  String compile() {
    return "${expression.compile()}?.map(${lambda.compile()}) /* $type */";
  }

  @override
  ExpressionNode resolve(LocalContext context) {
    expression = expression.resolve(context);
    expression = typeAssert(
      expression,
      const ListExpressionType(ExpressionType.unknown),
    );

    context = context.withImplicitLambdaParameters([
      new LambdaParameter(
        type: (expression.type as ListExpressionType).elementType,
      ),
    ]);
    lambda = lambda.resolve(context);
    lambda = typeAssert(lambda, ExpressionType.lambda);

    return this;
  }

  @override
  ExpressionType get type => lambda.body.type.wrapList();
}

class WhereNode extends ExpressionNode with ConcreteTypedNode {
  ExpressionNode expression;
  LambdaNode lambda;

  WhereNode(AqlContext context, this.expression, this.lambda) : super(context);

  @override
  String compile() {
    return "${expression.compile()}?.where(${lambda.compile()})";
  }

  @override
  ExpressionNode resolve(LocalContext context) {
    expression = expression.resolve(context);
    expression = typeAssert(
      expression,
      const ListExpressionType(ExpressionType.unknown),
    );

    context = context.withImplicitLambdaParameters([
      new LambdaParameter(
        type: (expression.type as ListExpressionType).elementType,
      ),
    ]);
    lambda = lambda.resolve(context);
    lambda = typeAssert(lambda, ExpressionType.lambda);

    return this;
  }

  @override
  ExpressionType get type => expression.type;
}

class SumNode extends ExpressionNode with ConcreteTypedNode {
  ExpressionNode expression;
  LambdaNode lambda;

  SumNode(AqlContext context, this.expression, this.lambda) : super(context);

  @override
  String compile() {
    return "${expression.compile()}?.map(${lambda.compile()})?.reduce((a, b) => a + b)";
  }

  @override
  ExpressionNode resolve(LocalContext context) {
    expression = expression.resolve(context);
    expression = typeAssert(
      expression,
      const ListExpressionType(ExpressionType.unknown),
    );

    context = context.withImplicitLambdaParameters([
      new LambdaParameter(
        type: (expression.type as ListExpressionType).elementType,
      ),
    ]);
    lambda = lambda.resolve(context);
    lambda = typeAssert(lambda, ExpressionType.lambda);

    return this;
  }

  // TODO: Proper expression type derived from +
  @override
  ExpressionType get type => ExpressionType.intType;
}

class SortByNode extends ExpressionNode with ConcreteTypedNode {
  ExpressionNode expression;
  LambdaNode lambda;

  SortByNode(AqlContext context, this.expression, this.lambda) : super(context);

  @override
  String compile() {
    return "context.sortBy(${expression.compile()}, ${lambda.compile()})";
  }

  @override
  ExpressionNode resolve(LocalContext context) {
    expression = expression.resolve(context);
    expression = typeAssert(
      expression,
      const ListExpressionType(ExpressionType.unknown),
    );

    context = context.withImplicitLambdaParameters([
      new LambdaParameter(
        type: (expression.type as ListExpressionType).elementType,
      ),
    ]);
    lambda = lambda.resolve(context);
    lambda = typeAssert(lambda, ExpressionType.lambda);

    return this;
  }

  @override
  ExpressionType get type => expression.type;
}
