// Copyright (c) 2017, dwayne. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'package:msk_pf/msk_pf.dart';
import 'package:file/local.dart';

main() async {
  final context = new PFContext(const LocalFileSystem().currentDirectory);
  await context.open();
  context.findAllEntries(0x6AF78CC0BE2926AF).forEach((entry) {
    print(entry.package.packageHeader.packageName);
  });
}
