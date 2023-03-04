export DFLAGS="-I=$HIPREME_ENGINE/modules/d_std/source \
-I=$HIPREME_ENGINE/dependencies/runtime/druntime/arsd-webassembly \
-d-version=PSVita \
-d-version=PSV \
-preview=shortenedMethods \
-mtriple=armv7a-unknown-newlib \
--revert=dtorfields \
-mcpu=cortex-a9 \
-O0 \
-g \
-float-abi=hard \
--relocation-model=static \
-d-version=CarelessAlocation"

dub -c psvita-main --compiler=ldc2 --arch=armv7a-unknown-newlib
dub -c psvita --compiler=ldc2 --arch=armv7a-unknown-newlib
rdmd tools/build/vita.d
