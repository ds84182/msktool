library msk.pf.src.id;

final _lut = new List<int>.generate(256, (i) => i)
    ..setRange(0x40, 0x5B, new Iterable.generate(0x5C-0x40, (i) => i+0x60));

int computeId(List<int> r3) {
  int r4 = 1;
  int r5 = (-0x340d631c) & 0xFFFFFFFF;
  int r6 = (-0x7bdddcdb) & 0xFFFFFFFF;
  const int r7 = 256;
  const int r8 = 435;

  for (int i=0; i<r3.length; i++) {
    int r0 = r3[i];
    r4 = (r6 * r8) >> 32;
    int r10 = _lut[r0];
    int r9 = (r10 >> 31) & 0xFFFFFFFF;
    r5 = (r5 * r8) & 0xFFFFFFFF;
    r0 = (r6 * r7) & 0xFFFFFFFF;
    r4 = (r4 + r5) & 0xFFFFFFFF;
    r6 = (r6 * r8) & 0xFFFFFFFF;
    r0 = (r4 + r0) & 0xFFFFFFFF;
    r5 = (r9 ^ r0) & 0xFFFFFFFF;
    r6 = (r10 ^ r6) & 0xFFFFFFFF;
  }
  return (r5 << 32) | r6;
}
