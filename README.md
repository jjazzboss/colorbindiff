# colorbindiff
A side-by-side visual and colorized diff for binary files. Show byte modifications but also additions and deletions, whatever the number of changed bytes. This is very convenient for example if you need to do reverse-engineering on a file format.

![screen snapshot](screen-snapshot.png)

### Usage
```bash
USAGE: perl colorbindiff [OPTIONS] FILE1 FILE2
```
### Options
```bash
--cols=N       : display N columns of bytes.diff Default is 16.
--no-color     : don't colorize output. Needed if you view the output in an editor.
--no-marker    : don't use the change markers (+ for addition, - for deletion, * for modified).
--no-ascii     : don't show the ascii columns.
--only-changes : only display lines with changes.
```
The script relies on the standard `diff` external command as found on Linux or Cygwin, so it must be in your path -if not, you'll need to update the script where `diff` is called.

Note that the algorithm is not suited for large and very different files.

# License
LGPL v3
