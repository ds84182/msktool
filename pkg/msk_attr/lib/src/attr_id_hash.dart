library msk.attr.src.attr_id_hash;

/*
r5 is an argument:
r5 = 0x811c9dc5

lis r7, 0x804F
lis r4, 0x0100
subi r7, r7, 14528
addi r6, r4, 403
b @start_loop

r7 = (0x804F0000 - 0x38C0) -- 0x804ec740 (points to an uppercase->lowercase table)
r4 = 0x01000000
r6 = r4 + 0x0193 -- 0x01000193

mullw r4, r5, r6
rlwinm r0, r0, 2, 0, 29 (0x3fffffff)
lwzx r0, r7, r0
xor r5, r0, r4
@start_loop:
lbz r0, 0 (r3)
addi r3, r3, 1
cmpwi r0, 0
bne @start_loop
b @end
...
@end:
mr r3, r5
blr

char *r3;
char r0;
while (r0 = *r3++) {
  r4 = r5 * r6;
  r0 = r7[r0 << 2];
  r5 = r0 ^ r4;
}
return r5;

// C function equivalent
// data: r3, type: r4, magic: r5
uint32_t hash(const char *data, uint32_t type, uint32_t magic) {
  switch (type) {
    case 1: {
      uint32_t c; // r0
      uint32_t *upperToLowerMap = 0x804ec740; // r7
      uint32_t magic2 = 0x01000193; // r6
      while (c = *data++) {
        uint32_t temp = magic * magic2; // r4
        c = upperToLowerMap[c];
        magic = c ^ temp;
      }
      return magic;
    }
  }
}

hash("island", 1, 0x811c9dc5) -> 0xBEB5360A
 */

final _lut = new List<int>.generate(256, (i) => i)
  ..setRange(0x40, 0x5B, new Iterable.generate(0x5C - 0x40, (i) => i + 0x60));

// Case insensitive FNV-1 hashing algorithm.
// Uses the standard 32 bit FNV_prime (0x01000193).
int calculateHash1(List<int> data, [int magic = 0x811c9dc5]) {
  const int magic2 = 0x01000193; // r6
  for (int i = 0; i < data.length; i++) {
    int c = data[i]; // r0
    int temp = (magic * magic2) & 0xFFFFFFFF; // r4
    c = _lut[c];
    magic = c ^ temp;
  }
  return magic;
}

// Case insensitive FNV-1 hashing algorithm.
// Uses the standard 32 bit offset_basis.
int attrId(String name) => calculateHash1(name.codeUnits);

String formatArrayIndex(int index) => "[${index.toString().padLeft(5, '0')}]";

// See 0x802b44b8
// The attr_id function call there uses the array attr id as the magic.
// attrIdArrayIndex(attrId("ChildRefSpecs"), 0) -> 0xc2fea746
int attrIdArrayIndex(int arrayId, int index) =>
    // [%05d]
    calculateHash1(formatArrayIndex(index).codeUnits, arrayId);
