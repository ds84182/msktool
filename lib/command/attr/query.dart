library msktool.command.attr.query;

import 'dart:async';
import 'package:msktool/command/attr.dart';
import 'aql.dart' show AqlContext, ExpressionNode, LocalContext, parseAql;

class AttrQueryCommand extends AttrSubCommand {
  @override
  String get description => "Runs a query on all collections, "
      "collections of a certain class, "
      "or child collections of a parent collection.";

  @override
  String get name => "query";

  @override
  List<String> get aliases => const ["qu", "q"];

  // Attribute Query Language, or AQL
  // Lets say we wanted to find all blocks that give a Domestic interest, then
  // sort by total Interest count (in all categories).
  // In normal Dart code (with some idiomatic accessors):
  // attr.block
  // .where((block) => block.ParentRefSpec == null && block.Interests.has(Interest.Domestic))
  // .sort((a, b) => a.Interests.total.compareTo(b.Interests.total))
  // Yuck.
  // I'd rather write this as:
  // FROM block WHERE ParentRefSpec IS NULL AND Interests HAS Interest.Domestic SORT BY Interests.Total ASCENDING
  // Which would use (abuse) observatory to generate Dart code to equivalent to the above.

  // A basic query is structured like this:
  // (FROM <source>)? (WHERE <expression>)? (SORT BY <expression> (ASCENDING|ASC|DESCENDING|DESC)?)?

  // FROM is where to query from.
  // <source> must resolve to a list of RefSpecs (or something convertible to it).
  // <source> can be a class name (disambiguated with the `class:` prefix).
  // <source> can be a RefSpec (ChildRefSpecs will be selected)
  //   (disambiguated with the `refspec:` prefix).
  // <source> can be another query returning RefSpecs.

  // WHERE is what to filter.
  // <expression> must be a boolean.

  // SORT BY is how to sort the results.
  // <expression> must resolve to something Comparable.

  // Test Queries:
  // mapnode:(map:leaf_map.MapNodeList)
  // mapnode:(map:leaf_map.MapNodeList) select { $.Position }
  // block:* where { $.ParentRefSpec is null and $.Interests has "Domestic" } sort by { $.total } ascending

  @override
  Future execute() async {
    final path = argResults.rest.isEmpty ? '' : argResults.rest.join(" ");
    print(path);

    final context = new AqlContext(await open());
    final result = parseAql(context, path);
    printInfo(result);
    ExpressionNode node =
        (result.value as ExpressionNode).resolve(const LocalContext());
    final compileResult = node.compile();
    printInfo(compileResult);
    final execResult = await context.execute(compileResult);
    print("Bench done");

    if (execResult is Iterable) {
      execResult.forEach(printInfo);
    } else {
      printInfo(execResult);
    }

//    print(new Key(context.attrContext, 0x6FEDAE4D).toString());
//    print(new Key(context.attrContext, const <int>[153, 232, 132, 231].reduce((a, b) => (a << 8) | b)).toString());

    // unlock:* where { $.Unlocks contains block:block_essence_social_angry }
    // unlock:* select { $.Unlocks where { $ is block:block_essence_social_angry } }
    // unlock:* where { $.Unlocks where { $ is block:block_essence_social_angry } is not empty }
    // reward:* where { $.Unlocks where { $ is unlock:social_essences } is not empty }
    // block:* where { $.Interests is not null } where { $.Orientation is null } select { list { $, $.Interests sum { $.score } } }
    // block:* where { $.Interests is not null } where { $.Orientation is null } select { list { $, $.Interests sum { $.score }, $.Interests, $.Cost } }
  }
}
