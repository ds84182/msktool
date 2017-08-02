library msk.attr.attr_log_grammar;

import 'package:petitparser/petitparser.dart';

export 'package:petitparser/petitparser.dart' show Failure, Success;

final _ws = whitespace().star();
final _id =
    ((letter() | anyOf('_.')) & (word() | anyOf('_.')).star()).flatten();
final _number = digit().plus().flatten().map(int.parse);

final attrId = (_id &
    string('[0x') &
    anyOf('0123456789ABCDEFabcdef')
        .times(8)
        .flatten()
        .map((String x) => int.parse(x, radix: 16)) &
    char(']')).permute(const [0, 2]);

final attrFlags = char('0').map((_) => const []) |
    (_ws &
            _id.separatedBy(_ws & char(',') & _ws, includeSeparators: false) &
            _ws)
        .pick(1);

final attrClass =
    (_ws & string('+ Class ') & attrId & _ws & attrFlags).permute(const [2, 4]);

final attrField = (_ws &
    string('+ ') &
    attrId &
    _ws &
    attrId &
    _ws &
    attrFlags &
    _ws &
    _number).permute(const [2, 4, 6, 8]);

final attrCollection = (_ws &
    string('+ ') &
    attrId &
    char(':') &
    attrId &
    _ws &
    attrFlags).permute(const [2, 4, 6]);
