#!/usr/bin/perl
#########################################################################
#
# COLORBINDIFF.PL : A side-by-side visual diff for binary files.
#                   Consult usage subroutine below for help.
#
# Copyright (C) 2021 Jerome Lelasseux jl@jjazzlab.com
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#
#########################################################################

use warnings;
use strict;
use Term::ANSIColor qw(colorstrip colored);
use Getopt::Long qw(GetOptions);
use File::Temp qw(tempfile);
use constant BLANK => "..";
use constant BUFSIZE =>  64 * 1024;	 # 64kB

sub usage
{
	print "USAGE: $0 [OPTIONS] FILE1 FILE2\n";
	print "Show a side-by-side binary comparison of FILE1 and FILE2. Show byte modifications but also additions and deletions, whatever the number of changed bytes. Rely on the 'diff' external command such as found on Linux or Cygwin. The algorithm is not suited for large and very different files.\n";	
	print "Author: Jerome Lelasseux \@2021\n";
	print "OPTIONS: \n";
	print " --cols=N       : display N columns of bytes.diff Default is 16.\n";
	print " --no-color     : don't colorize output. Needed if you view the output in an editor.\n";
	print " --no-marker    : don't use the change markers (+ for addition, - for deletion, * for modified).\n";
	print " --no-ascii     : don't show the ascii columns.\n";
	print " --only-changes : only display lines with changes.\n";
	print " --no-header    : don't print the header line.\n";
	exit;
}

# Command line arguments
my $maxCols=16;
my $noColor=0;
my $noMarker=0;
my $noAscii=0;
my $noCommon=0;
my $noHeader=0;
GetOptions(
	'cols=i' => \$maxCols,
	'no-ascii' => \$noAscii,
    'no-color' => \$noColor,
    'no-marker' => \$noMarker,
	'only-changes' => \$noCommon,
	'no-header' => \$noHeader
) or usage();
usage() unless ($#ARGV == 1);
my ($file1, $file2) = (@ARGV);


# Convert input files into hex lists
my $fileHex1 = createHexListFile($file1);
my $fileHex2 = createHexListFile($file2);

# Print a header line
if (! $noHeader)
{
	my $asciiSpace = $noAscii ? "" : " " x $maxCols;	
	my $s = $noMarker ? " " : "  ";
	my $header="OFFSET ${s}00${s}01${s}02${s}03${s}04${s}05${s}06${s}07${s}08${s}09${s}0A${s}0B${s}0C${s}0D${s}0E${s}0F $asciiSpace  OFFSET ${s}00${s}01${s}02${s}03${s}04${s}05${s}06${s}07${s}08${s}09${s}0A${s}0B${s}0C${s}0D${s}0E${s}0F\n";
	if (!$noColor)
	{
		$header = colored($header, 'magenta');
	}
	print $header;
}

# Process diff -y output to get an easy-to-read side-by-side view
my $colIndex=0;
my $oldPtr=0;
my $newPtr=0;
my $oldLineBuffer = sprintf("0x%04X ", 0);
my $newLineBuffer = sprintf("0x%04X ", 0);
my $oldCharBuffer;
my $newCharBuffer;
my $isDeleting=0; 
my $isAdding=0; 
my $isUnchangedLine=1;
open(my $fh, '-|', qq(diff -y $fileHex1 $fileHex2)) or die $!;	
while (<$fh>)     
{
	# Parse line by line the output of the 'diff -y' on the 2 hex list files. 
	# We expect: 
	# "xx      | yy" for a modified byte
	# "        > yy" for an added byte
	# "xx      <"    for a deleted byte
	# "xx        xx" for identicial bytes
	
	my ($oldByte, $newByte);
	my ($oldChar, $newChar);
   if (/\|/)
   {
		# changed
		if ($isDeleting || $isAdding)
		{
			printLine($colIndex);
		}
		$isAdding=0; 		
		$isDeleting=0; 
		$isUnchangedLine=0;
		
		/([a-fA-F0-9]+)([^a-fA-F0-9]+)([a-fA-F0-9]+)/;
		$oldByte=formatByte($1, 3);
		$oldChar=toPrintableChar($1,3);		
		$newByte=formatByte($3, 3);
		$newChar=toPrintableChar($3,3);
		$oldPtr++;
		$newPtr++;
   } elsif (/</)
   {
		# deleted in new
		if ($isAdding)
		{
			printLine($colIndex);
		}
		$isAdding=0; 		
		$isDeleting=1; 		
		$isUnchangedLine=0;		
		
		/([a-fA-F0-9]+)/;
		$oldByte=formatByte($1, 2);
		$oldChar=toPrintableChar($1, 2);		
		$newByte=formatByte(BLANK, 2);
		$newChar=colorize(".", 2);		
		$oldPtr++;
   } elsif (/>/)
   {
		# added in new
		if ($isDeleting)
		{
			printLine($colIndex);
		}			
		$isAdding=1;		
		$isDeleting=0;  
		$isUnchangedLine=0;		
		
		/([a-fA-F0-9]+)/;
		$oldByte=formatByte(BLANK, 1);
		$oldChar=colorize(".", 1);				
		$newByte=formatByte($1, 1);			
		$newChar=toPrintableChar($1, 1);		
		$newPtr++;		
   }      
   else
   {
		# unchanged
		if ($isDeleting || $isAdding)
		{
			printLine($colIndex);
		}				
		$isDeleting=0; 
		$isAdding=0; 
			
		/([a-fA-F0-9]+)([^a-fA-F0-9]+)([a-fA-F0-9]+)/;
		$oldByte=formatByte($1, 0);
		$oldChar=toPrintableChar($1, 0);		
		$newByte=formatByte($3, 0);	
		$newChar=toPrintableChar($3, 0);		
		$oldPtr++;				
		$newPtr++;		
   }       
   
   # Append the bytes to the old and new buffers
	$oldLineBuffer .= $oldByte;   
	$oldCharBuffer .= $oldChar;
   	$newLineBuffer .= $newByte;
	$newCharBuffer .= $newChar;
	$colIndex++;
	if ($colIndex == $maxCols)
	{
		printLine();
	} 
}

printLine($colIndex);	# Possible remaining line


#================================================================
# subroutines
#================================================================

# $1 a string representing a data byte
# $2 0=unchanged, 1=added, 2=deleted, 3=changed
# return the formatted string (color/maker)
sub formatByte
{
	my ($byte, $type) = @_;
	my $res;
	if (!$noMarker)
	{
		if ($type == 0 || $byte eq BLANK) 	{ $res = "  " . $byte; }	# unchanged or blank
		elsif ($type == 1) 	{ $res = " +" . $byte; }	# added
		elsif ($type == 2) 	{ $res = " -" . $byte; }	# deleted
		elsif ($type == 3) 	{ $res = " *" . $byte; }	# changed
		else  { die "Error"; }
	} else
	{
		$res = " " . $byte;
	}
	$res = colorize($res, $type);
	return $res;
}

# $1 a string 
# $2 0=unchanged, 1=added, 2=deleted, 3=changed
# return the colorized string according to $2
sub colorize
{
	my ($res, $type) = @_;
	if (!$noColor)
	{		
		if ($type == 0) 	{  }		# unchanged
		elsif ($type == 1) 	{ $res = colored($res, 'bright_green'); }		# added
		elsif ($type == 2) 	{ $res = colored($res, 'bright_red'); }			# deleted
		elsif ($type == 3) 	{ $res = colored($res, 'bright_cyan'); }		# changed
		else   { die "Error"; }	
	}
	return $res;
}

# Print the buffered line
sub printLine
{
	if (length($oldLineBuffer) <=10)
	{
		return;		# no data to display
	}
	
	if (!$isUnchangedLine)
	{
		# Colorize and add a marker to the address of each line if some bytes are changed/added/deleted 
		my $prefix = substr($oldLineBuffer, 0, 6) . ($noMarker ? " " : "*");
		$prefix = colored($prefix, 'bright_magenta') unless $noColor;
		$oldLineBuffer =~ s/^......./$prefix/;
		$prefix = substr($newLineBuffer, 0, 6) . ($noMarker ? " " : "*");
		$prefix = colored($prefix, 'bright_magenta') unless $noColor;
		$newLineBuffer =~ s/^......./$prefix/;		
	}
	
	my $oldCBuf = $noAscii ? "" : $oldCharBuffer;
	my $newCBuf = $noAscii ? "" : $newCharBuffer;
	my $spacerChars = $noAscii ? "" : (" " x ($maxCols - $colIndex));			
	my $spacerData = ($noMarker ? "   " : "    ") x ($maxCols - $colIndex);	
	if (!($noCommon && $isUnchangedLine))
	{	
		print "${oldLineBuffer}${spacerData} ${oldCBuf}${spacerChars}  ${newLineBuffer}${spacerData} ${newCBuf}\n";    
	}
	
	# reset buffers and counters
	$oldLineBuffer = sprintf("0x%04X ", $oldPtr);
	$newLineBuffer = sprintf("0x%04X ", $newPtr);
    $oldCharBuffer = "";
	$newCharBuffer = "";
	$colIndex=0;
	$isUnchangedLine=1;		
}

# Convert a hex byte string into a printable char, or '.'.
# $1 = hex str such as A0
# $2 0=unchanged, 1=added, 2=deleted, 3=changed
# return the corresponding char, possibly colorized
sub toPrintableChar
{
	my ($hexByte, $type) = @_;
	my $char = chr(hex($hexByte));
	$char =  ($char =~ /[[:print:]]/) ? $char : ".";
	return colorize($char, $type);
}

# Convert file $1 into a text file with 1 hex byte per line.
# $1=input file name
# return the output file name
sub createHexListFile
{
	my ($inFileName) = @_;
	my $buffer;	
	my $in_fh;
	open($in_fh,  "<:raw", $inFileName) || die "$0: cannot open $inFileName for reading: $!";	
	my ($out_fh, $filename) = tempfile();

	while (my $nbReadBytes = read($in_fh, $buffer, BUFSIZE)) 
	{
		my @hexBytes = unpack("H2" x $nbReadBytes, $buffer);
		foreach my $hexByte (@hexBytes)
		{	
			print $out_fh "$hexByte\n" || die "couldn't write to $out_fh: $!";	
		}
	}
	close($in_fh);
	return $filename;
}
