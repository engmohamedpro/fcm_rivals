#!/usr/bin/env python3
"""Pass 2: restore the store-composition family into the class (extension
scope does not propagate through providers.dart re-imports), and instead
move only library-private internals (_toBasePlayer + the unnamed
AppDatabase ledger extension) into a part file. Task
2026-11-06_app-structure_finish-collection-facade-split. Byte-identity
asserted against the HEAD blob.

Current-state anchors (main file after pass 1 + directive fix):
  40: part 'collection_store_dataset.dart';
  41: part 'collection_store_composition.dart';   (to be dropped)
  42: (blank)
  43: class CollectionStore {
  811: (blank)
  812:   /// Adapts a persisted player row to the domain model.
  813-826: _toBasePlayer
  827: (blank)
  828: }            (class close)
  829: (blank)
  830: extension on AppDatabase {
  859: }            (extension close, no trailing blank)
"""
import os
import subprocess

MAIN = 'lib/features/collection/collection_store.dart'
PART_B = 'lib/features/collection/collection_store_composition.dart'
PART_I = 'lib/features/collection/collection_store_internals.dart'

cur = open(MAIN).read().split('\n')
assert len(cur) == 860 and cur[859] == '', f'unexpected main tail {len(cur)}'
assert cur[39] == "part 'collection_store_dataset.dart';", repr(cur[39])
assert cur[40] == "part 'collection_store_composition.dart';", repr(cur[40])
assert cur[827] == '}', repr(cur[827])
assert cur[829] == 'extension on AppDatabase {', repr(cur[829])
assert cur[858] == '}', repr(cur[858])
assert cur[811] == '  /// Adapts a persisted player row to the domain model.', repr(cur[811])
assert cur[825] == '  );', repr(cur[825])

# composition members: verbatim from the part file, wrapper dropped
pb = open(PART_B).read().rstrip('\n').split('\n')
assert pb[9].startswith('extension StoreCompositionOps'), repr(pb[9])
assert pb[-1] == '}', repr(pb[-1])
comp = pb[10:-1]
assert len(comp) == 42, len(comp)

head = subprocess.run(
    ['git', 'show', 'HEAD:lib/features/collection/collection_store.dart'],
    capture_output=True, text=True).stdout.split('\n')
assert len(head) == 1050 and head[1049] == '}', 'unexpected HEAD shape'
assert comp == head[976:1018], 'composition block not byte-identical to HEAD'

rowmap = cur[811:826]            # lines 812-826: doc + _toBasePlayer
assert rowmap == head[960:975], 'rowmap not byte-identical'
appdb = cur[829:859]             # lines 830-859: the unnamed extension
assert appdb == head[1020:1050], 'appdb extension not byte-identical'

HEADER_I = """part of 'collection_store.dart';

/// Library-private internals of [CollectionStore] (extracted from the
/// facade, app-structure review task
/// `2026-11-06_app-structure_finish-collection-facade-split`): the
/// persisted-row-to-domain mapper and the AppDatabase ledger append used
/// inside caller-owned transactions. Pure relocation — bodies unchanged;
/// private scope, so no call site outside this library is affected.
extension _RowMapping on CollectionStore {""".split('\n')

part_i = HEADER_I + rowmap + ['}', ''] + appdb

main = (cur[:40]                       # lines 1-40, incl. dataset part
        + ["part 'collection_store_internals.dart';"]
        + cur[41:811]                  # blank + class body through '  }'
        + comp                         # composition restored in the class
        + cur[827:828])                # class close '}'

open(PART_I, 'w').write('\n'.join(part_i) + '\n')
open(MAIN, 'w').write('\n'.join(main) + '\n')
os.remove(PART_B)
print('main lines:', len(main))
print('internals lines:', len(part_i))
