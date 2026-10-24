#!/usr/bin/env python3
"""Write the slab allocator, verbatim from runtime/lang_runtime.c, to slab_body.inc
so slab_stress.c can compile it on its own (ASan, TSan, many threads)."""
from pathlib import Path
here = Path(__file__).resolve().parent
src = (here.parent.parent / "runtime" / "lang_runtime.c").read_text()
a = src.index("// ---- slab ----")
b = src.index("// ---- end slab ----")
(here / "slab_body.inc").write_text(src[a:b])
print("wrote", here / "slab_body.inc")
