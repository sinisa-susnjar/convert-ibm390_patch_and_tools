# Convert::IBM390 (v0.29) patch

Copy the patch file IBM390lib.ccc.patch to Convert-IBM390-0.29/d/IBM390lib.ccc and apply it with 'patch -p0 <IBM390lib.ccc.patch', then do a 'perl Makefile.PL', 'make', 'make test' and 'make install' as usual.
Performance relevant changes are enclosed in #if USE_OPT ... #endif brackets.

I made the changes for a project where I had to decode multi gigabyte EBCDIC encoded files consisting mostly of packed decimals and every second that could be saved during processing counted against the total runtime of the batch processes involved.
The performance gains for the encoding case (ASCII->EBCDIC) are pretty good, cutting the runtime approx. in half, while the gains for the decoding (EBCDIC->ASCII) case where not too impressive (only around 5% - but still an improvement).

# The command line conv.pl tool

The attached 'conv.pl' tool is a self contained example on how to use the great Convert::IBM390 module and can also be used for real conversion jobs - call './conv.pl --man' to see the manpage and example usage of the tool.
