# smolcat
This is a clone of cat that works as expected, except it does not default to stdin with no arguments.
Right now the smallest binary I can produce (without trimming some sections) is 608 bytes. After trimming the data after the last string the binary is currently 392 bytes, and executes properly (on linux 4.4.0)