#!/usr/bin/env python3
"""Extract CollectionStore method families into part files (task 2026-11-06_app-structure_finish-collection-facade-split).

Pure relocation: slices are moved byte-identical from collection_store.dart
into two part files (dataset-import family, store-composition family), each
wrapped in a public-named extension so every external call site keeps
resolving. Verifies byte-identity before writing.
"""
import subprocess, sys

MAIN = 'lib/features/collection/collection_store.dart'
PART_A = 'lib/features/collection/collection_store_dataset.dart'
PART_B = 'lib/features/collection/collection_store_composition.dart'

src = open(MAIN).read().split('\n')
assert len(src) == 1050 and src[1049] == '}', f'unexpected tail {len(src)} {src[-1]!r}'

# sanity anchors (0-indexed)
assert src[187] == '  }', repr(src[187])                     # createClub close (line 188)
assert src[188].strip() == '/// pack drawing before any update was applied in this session).', repr(src[188])  # stray doc fragment (line 189)
assert src[338] == '  }', repr(src[338])                     # applyDatasetUpdate close (line 339)
assert src[339] == '', repr(src[339])                        # blank (line 340)
assert src[975] == '', repr(src[975])                        # blank (line 976)
assert src[976].startswith('  // --- Club / squad'), repr(src[976])  # line 977
assert src[1017].endswith('costs: costs);'), repr(src[1017]) # line 1018
assert src[1018] == '}', repr(src[1018])                     # class close (line 1019)

slice_a = src[188:339]   # lines 189-339 (151 lines)
slice_b = src[976:1018]  # lines 977-1018 (42 lines)

HEADER_A = """part of 'collection_store.dart';

/// Dataset import family of [CollectionStore] (extracted from the facade,
/// app-structure review task
/// `2026-11-06_app-structure_finish-collection-facade-split`): registry
/// warm-up, bundled-dataset import and the transactional dataset update
/// with removed-player compensation. Pure relocation — bodies unchanged;
/// part of the store library so the private registry state stays
/// reachable. Public-named because its members are the facade's public
/// API (providers, the simulator and tests call them directly), so every
/// existing call site keeps resolving with zero edits.
extension DatasetImportOps on CollectionStore {"""

HEADER_B = """part of 'collection_store.dart';

/// Store-composition family of [CollectionStore] (extracted from the
/// facade, app-structure review task
/// `2026-11-06_app-structure_finish-collection-facade-split`): the club /
/// squad / campus pass-through members that delegate to the focused
/// stores — the compatibility facade. Pure relocation — bodies unchanged.
/// Public-named because its members are the facade's public API, so every
/// existing call site keeps resolving with zero edits.
extension StoreCompositionOps on CollectionStore {"""

part_a = HEADER_A.split('\n') + slice_a + ['}']
part_b = HEADER_B.split('\n') + slice_b + ['}']

# main file: drop the two slices, insert part directives after the imports
PART_LINES = [
    '',
    "part 'collection_store_dataset.dart';",
    "part 'collection_store_composition.dart';",
]
main = src[:188] + PART_LINES + src[339:976] + src[1018:]

def fmt(lines):
    return '\n'.join(lines) + '\n'

# byte-identity verification: re-derive the slices from the new part files
pa = fmt(part_a).split('\n')
pb = fmt(part_b).split('\n')
ra = pa[pa.index('extension DatasetImportOps on CollectionStore {') + 1: pa.index('}', pa.index('extension DatasetImportOps on CollectionStore {'))]
rb = pb[pb.index('extension StoreCompositionOps on CollectionStore {') + 1: pb.index('}', pb.index('extension StoreCompositionOps on CollectionStore {'))]
assert ra == slice_a, 'slice A not byte-identical'
assert rb == slice_b, 'slice B not byte-identical'

open(PART_A, 'w').write(fmt(part_a))
open(PART_B, 'w').write(fmt(part_b))
open(MAIN, 'w').write(fmt(main))
print('part A lines:', len(part_a))
print('part B lines:', len(part_b))
print('main lines:', len(main))
