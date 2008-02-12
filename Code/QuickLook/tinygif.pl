#!/usr/bin/perl

## tinygif
## World's Smallest Gif
## 35 bytes, 43 if transparent

use strict;
my($RED,$GREEN,$BLUE,$GHOST,$CGI);

## Adjust the colors here, from 0-255
$RED   = 191;
$GREEN = 191;
$BLUE  = 191;

## Set $GHOST to 1 for a transparent gif, 0 for normal
$GHOST = 0;

## Set $CGI to 1 if writing to a web browser, 0 if not
$CGI = 0;

$CGI && printf "Content-Length: %d\nContent-Type: image/gif\n\n", 
  $GHOST?43:35;
printf "GIF89a\1\0\1\0%c\0\0%c%c%c\0\0\0%s,\0\0\0\0\1\0\1\0\0%c%c%c\1\0;",
  144,$RED,$GREEN,$BLUE,$GHOST?pack("c8",33,249,4,5,16,0,0,0):"",2,2,4;
