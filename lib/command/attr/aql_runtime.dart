library msktool.command.attr.aql_runtime;

import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'package:charcode/ascii.dart';
import 'package:msk_attr/msk_attr.dart';
import 'dart:mirrors';
import 'package:path/path.dart' as path;

class AqlContext {
  final AttrContext attrContext;
  AqlContext(this.attrContext);

  Iterable<RefSpec> makeRefSpecs(
      ClassKey classKey, Iterable<CollectionKey> collectionKeys) {
    return collectionKeys.map(classKey.withCollection);
  }

  static final int childRefSpecsId = attrId("ChildRefSpecs");

  Iterable<RefSpec> childrenOf(RefSpec parent) {
    return parent.classOnly
        .lookupCollections()
        .where((c) => c.parent == parent.collectionKey)
        .map((c) => new RefSpec.fromCollection(attrContext, c));
  }

  Iterable<RefSpec> makeChildRefSpecs(RefSpec parent) {
    // TODO: Lazy ChildRefSpecs list
    return AttrCollectionHelper.readField(
      attrContext,
      parent.lookup(),
      parent.classOnly.lookupField(childRefSpecsId),
    );
  }

  Iterable<RefSpec> makeRefSpecSpread(ClassKey classKey) {
    return classKey
        .lookupCollections()
        .map((collection) => classKey.withCollection(collection.id));
  }

  T readField<T>(RefSpec refSpec, int id) {
    return AttrCollectionHelper.readField(
      attrContext,
      refSpec.lookup(),
      refSpec.classOnly.lookupField(id),
    ) as T;
  }

  T readFieldRaw<T>(AttrCollection collection, AttrField field) {
    return AttrCollectionHelper.readField(
      attrContext,
      collection,
      field,
    ) as T;
  }

  List<T> sortBy<T>(Iterable<T> iter, Comparable toCompare(T a)) {
    return iter.toList(growable: false)
      ..sort((a, b) => toCompare(a).compareTo(toCompare(b)));
  }

  static final Map<int, Function> _executionFuncs = <int, Function>{};

  Future<Object> execute(String code) async {
    final msktool =
        await Isolate.resolvePackageUri(Uri.parse("package:msktool/"));
    print(msktool);

    final rand = Random.secure();

    final aqlLoadPath = path.join(File.fromUri(msktool).parent.path,
        "aql_load_${String.fromCharCodes(List.generate(8, (_) => rand.nextInt(26) + $A))}.dart");

    await File(aqlLoadPath).writeAsString(
      "import 'package:msktool/command/attr/aql_runtime.dart';"
          "import 'package:msk_attr/msk_attr.dart';"
          "dynamic main(AqlContext context) {"
          "final attrContext = context.attrContext;"
          "return $code;"
          "}",
    );

    final library =
        await currentMirrorSystem().isolate.loadUri(File(aqlLoadPath).uri);

    _executionFuncs[hashCode] = library.getField(#main).reflectee;

//    AqlContext._executionFuncs[745654887] = (AqlContext context) {
//      final attrContext = context.attrContext;
//      return context
//          .makeRefSpecs(
//              new ClassKey(attrContext, 3083299045 /* mapnode */),
//              context.readField<List<CollectionKey>>(
//                  new ClassKey(attrContext, 1048449605 /* map */)
//                      .withCollection(new CollectionKey(
//                          attrContext, 219271718 /* leaf_map */)),
//                  823340797 /* MapNodeList */) /* List<CollectionKey> */) /* List<RefSpec (inferred as mapnode)> */ ?.map(
//              (RefSpec $ /* RefSpec (inferred as mapnode) */) => context.readField<
//                      dynamic>($,
//                  1578750580 /* Position */) /* dynamic */) /* List<dynamic> */;
//    };

    /*final stopwatch = new Stopwatch();
    final func = (AqlContext context) {
      final attrContext = context.attrContext;
      const useIterableFunctions = const bool.fromEnvironment(
          "use.iterable.functions",
          defaultValue: false);

      final queryFunc = useIterableFunctions
          ? () {
              return context
                  .makeRefSpecSpread(
                      new ClassKey(attrContext, 4001580976 /* block */))
                  ?.where((RefSpec $ /* RefSpec (inferred as block) */) =>
                      (context.readField<List<InterestScore>>($,
                          2891037458 /* Interests */) /* List<InterestScore> */) !=
                      (null))
                  ?.where((RefSpec $ /* RefSpec (inferred as block) */) =>
                      (context.readField<dynamic>(
                          $, 443052465 /* Orientation */) /* Unknown */) ==
                      (null))
                  ?.map((RefSpec $ /* RefSpec (inferred as block) */) =>
                      <dynamic>[
                        $,
                        context
                            .readField<List<InterestScore>>($,
                                2891037458 /* Interests */) /* List<InterestScore> */ ?.map((InterestScore
                                    $ /* InterestScore */) =>
                                $.score)
                            ?.reduce((a, b) => a + b),
                        context.readField<List<InterestScore>>($,
                            2891037458 /* Interests */) /* List<InterestScore> */,
                        context.readField<dynamic>(
                            $, 3771049410 /* Cost */) /* Unknown */
                      ] /* List<Unknown> */); /* List<List<Unknown>> */
            }
          : () sync* {
              final c = new ClassKey(attrContext, 4001580976);
              final ca = c.lookupField(2891037458);
              final cb = c.lookupField(443052465);
              final cc = c.lookupField(3771049410);
              var $ca;
              for (final $ in c.lookupCollections()) {
                $ca = readFieldRaw<dynamic>($, ca);
                if (!($ca != (null))) continue;
                if (!((readFieldRaw<dynamic>($, cb)) == (null))) continue;
                yield [
                  $,
                  $ca.map((dynamic $) => $.score).reduce((a, b) => a + b),
                  $ca,
                  context.readFieldRaw($, cc)
                ];
              }
            };

      return context.sortBy(
          queryFunc(), (List<dynamic> $ /* List<Unknown> */) => $[1]);
    };

    print(func);*/
    final func = _executionFuncs.remove(hashCode);
//    final execTimes = <double>[];
//    for (int i = 0; i < 1000; i++) {
//      stopwatch.start();
//      dynamic result;
//      result = func(this);
//      if (result is Iterable) result = result.toList(growable: false);
//      stopwatch.stop();
//      execTimes.add(stopwatch.elapsedTicks / stopwatch.frequency * 1000.0);
//      stopwatch.reset();
//    }
//    return [
//      execTimes.reduce((a, b) => a < b ? a : b),
//      execTimes.reduce((a, b) => a + b) / execTimes.length,
//      execTimes.reduce((a, b) => a > b ? a : b)
//    ];
    dynamic result;
    result = func(this);
    if (result is Iterable) result = result.toList(growable: false);
    return result;
  }
}
