#import "NSString-Utilities.h"
//#import <OmniFoundation/NSMutableString-OFExtensions.h>

#import "OmniCompatibility.h"

@implementation NSString(utils)

+ stringWithFileSystemRepresentation:(const char*)path
{
    return [[NSFileManager defaultManager] stringWithFileSystemRepresentation:path length:strlen(path)];
}

+ (NSString *)stringWithPString:(Str255)pString;
{
    return [NSString stringWithCString:(const char *)pString+1 length:pString[0]];
}

- (void)getPString:(Str255)outString
{
    [self getCString:(char *)outString+1 maxLength:255];
    outString[0] = MIN((unsigned)255, [self cStringLength]);
}

// converts all colons to /  SNG
// DO NOT CHANGE THIS, otherwise the Copy Engine will break!
+ (NSString*)stringWithHFSUniStr255:(const HFSUniStr255*)hfsString;
{
    // old code seemed to have a memory leak?
    // NSMutableString* result = [NSMutableString stringWithCharacters:hfsString->unicode length:hfsString->length];
    // [result replace:@"/" with:@":"];
    
    NSString* result;
    int i, cnt=hfsString->length;
    unichar *buffer = malloc(cnt * sizeof(unichar));
    unichar character;
    
    for (i=0;i<cnt;i++)
    {
        character = hfsString->unicode[i];
        
        if (character == '/')
            character = ':';
        
        buffer[i] = character;
    }
    
    result = [NSString stringWithCharacters:buffer length:cnt];
    
    free(buffer);
    
    return result;
}

// converts all / to colons SNG
// DO NOT CHANGE THIS, otherwise the Copy Engine will break!
- (void)getHFSUniStr255:(HFSUniStr255*)hfsString
{
    int length = MIN([self length], (unsigned)255);
    NSString* convertedString;

    convertedString = [self stringByReplacing:@":" with:@"/"];

    [convertedString getCharacters:hfsString->unicode range:NSMakeRange(0, length)];
    hfsString->length = length;
}

- (NSString*)stringByReplacing:(NSString *)value with:(NSString *)newValue;
{
    NSMutableString *newString = [NSMutableString stringWithString:self];

    [newString replaceOccurrencesOfString:value withString:newValue options:NSLiteralSearch range:NSMakeRange(0, [newString length])];

    return newString;
}

- (NSString*)stringByReplacingValuesInArray:(NSArray *)values withValuesInArray:(NSArray *)newValues;
{
    unsigned i, cnt = [values count];
    NSString *tempString=self;

    for (i=0; i < cnt; i++)
    {
        NSString *newValue;

        newValue=[tempString stringByReplacing:[values objectAtIndex:i] with:[newValues objectAtIndex:i]];
        tempString=newValue;
    }
    return tempString;
}

- (NSString*)stringByDeletingSuffix:(NSString *)suffix;
{
    if ([[self substringFromIndex:([self length]-[suffix length])] isEqual:suffix])
        return [self substringToIndex:([self length]-[suffix length])];
    return nil;
}

- (NSString*)stringWithShellCharactersQuoted
{
    NSString *tempStr = [self stringByReplacing:@"'" with:@"'\\''"];
    return [NSString stringWithFormat:@"'%@'",tempStr];
}

- (NSString*)stringWithShellCharactersQuotedold;
{
    NSString *tempStr;
    tempStr=[self stringByReplacing:@"\"" with:@"\\\""];
    tempStr=[tempStr stringByReplacing:@" " with:@"\\ "];
    tempStr=[tempStr stringByReplacing:@":" with:@"\\:"];
    tempStr=[tempStr stringByReplacing:@"'" with:@"\\'"];
    tempStr=[tempStr stringByReplacing:@"(" with:@"\\("];
    tempStr=[tempStr stringByReplacing:@")" with:@"\\)"];
    tempStr=[tempStr stringByReplacing:@"[" with:@"\\["];
    tempStr=[tempStr stringByReplacing:@"]" with:@"\\]"];
    tempStr=[tempStr stringByReplacing:@"!" with:@"\\!"];
    return [NSString stringWithFormat:@"\"%@\"",tempStr];
}

- (BOOL)stringContainsValueFromArray:(NSArray *)theValues
{
    NSEnumerator *overItems;
    id eachItem;

    overItems=[theValues objectEnumerator];
    while ((eachItem = [overItems nextObject]))
    {
        NSRange foundSourceRange;

        foundSourceRange=[self rangeOfString:eachItem options:NSLiteralSearch];
        if (foundSourceRange.length!=0)
            return YES;
    }

    return NO;
}

- (BOOL)isEqualToStringCaseInsensitive:(NSString *)str
{
    // returns - NSOrderedAscending, NSOrderedSame, NSOrderedDescending
    return ([self caseInsensitiveCompare:str] == NSOrderedSame);
}

- (NSArray*)linesFromString:(NSString**)outRemainder;
{
    NSMutableArray* result = [NSMutableArray arrayWithCapacity:20];
    unsigned length = [self length];
    NSString *line;
    NSRange range = NSMakeRange(0, 1);
    unsigned start, end, contentsEnd;

    // getLineStart can throw exceptions
    NS_DURING

        // must parse out the lines, more than one line will be returned
        while (NSMaxRange(range) <= length)
        {
            [self getLineStart:&start end:&end contentsEnd:&contentsEnd forRange:range];

            if ((start >= range.location) && (start != end) && (end != contentsEnd))
            {
                line = [self substringWithRange:NSMakeRange(start, contentsEnd-start)];
                [result addObject:line];

                range = NSMakeRange(end, 1);
            }
            else
            {
                if (outRemainder)
                {
                    if (end == contentsEnd)
                        *outRemainder = [self substringWithRange:NSMakeRange(start, contentsEnd-start)];
                    else
                        *outRemainder = nil;
                }

                break;
            }
        }

        NS_HANDLER
            ;
        NS_ENDHANDLER

        return result;
}

- (NSString*)getFirstLine;
{
    NSString *line=self;
    NSRange range = NSMakeRange(0, 1);
    unsigned start, end, contentsEnd;

    if (NSMaxRange(range) <= [self length])
    {
        [self getLineStart:&start end:&end contentsEnd:&contentsEnd forRange:range];

        if ((start >= range.location) && (start != end) && (end != contentsEnd))
            line = [self substringWithRange:NSMakeRange(start, contentsEnd-start)];
    }

    return line;
}

- (NSString*)stringWithRegularExpressionCharactersQuoted;
{
    NSString *result;
    result=[self stringByReplacing:@"\"" with:@"\\\""];
    result=[result stringByReplacing:@" " with:@"\\ "];
    result=[result stringByReplacing:@":" with:@"\\:"];
    result=[result stringByReplacing:@"'" with:@"\\'"];
    result=[result stringByReplacing:@"(" with:@"\\("];
    result=[result stringByReplacing:@")" with:@"\\)"];
    result=[result stringByReplacing:@"[" with:@"\\["];
    result=[result stringByReplacing:@"]" with:@"\\]"];
    result=[result stringByReplacing:@"!" with:@"\\!"];
    result=[result stringByReplacing:@"?" with:@"\\?"];
    result=[result stringByReplacing:@"*" with:@"\\*"];
    result=[result stringByReplacing:@"+" with:@"\\+"];

    // SNG added & ; |
    result=[result stringByReplacing:@"&" with:@"\\&"];
    result=[result stringByReplacing:@";" with:@"\\;"];
    result=[result stringByReplacing:@"|" with:@"\\|"];

    return result;
}

- (NSString*)URLEncodedString;
{
    CFStringRef stringRef = CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef) self, NULL, NULL, kCFStringEncodingUTF8);

    NSString *result = [NSString stringWithString:(NSString*)stringRef];
    CFRelease(stringRef);
    
    return result;
}


// converts a POSIX path to an HFS path
- (NSString*)HFSPath;
{
    CFURLRef fileURL;
    NSString* hfsPath=nil;

    fileURL = CFURLCreateWithFileSystemPath(NULL, (CFStringRef)self, kCFURLPOSIXPathStyle, NO);

    if (fileURL)
    {
        CFStringRef hfsRef = CFURLCopyFileSystemPath(fileURL, kCFURLHFSPathStyle);
        if (hfsRef)
        {
            // copy into an autoreleased NSString
            hfsPath = [NSString stringWithString:(NSString*)hfsRef];

            CFRelease(hfsRef);
        }

        CFRelease(fileURL);
    }

    return hfsPath;
}

// converts a HFS path to a POSIX path
- (NSString*)POSIXPath;
{
    CFURLRef fileURL;
    NSString* posixPath=nil;

    fileURL = CFURLCreateWithFileSystemPath(NULL, (CFStringRef)self, kCFURLHFSPathStyle, NO);

    if (fileURL)
    {
        CFStringRef posixRef = CFURLCopyFileSystemPath(fileURL, kCFURLPOSIXPathStyle);

        if (posixRef)
        {
            // copy into an autoreleased NSString
            posixPath = [NSString stringWithString:(NSString*)posixRef];

            CFRelease(posixRef);
        }

        CFRelease(fileURL);
    }

    return posixPath;
}

- (BOOL)isEndOfWordAtIndex:(unsigned)anIndex;
{
    if (anIndex == [self length])
        return YES;
    else if (anIndex >=0 && anIndex < [self length])
    {
        NSCharacterSet *wordSep;
        unichar ch;

        ch = [self characterAtIndex:anIndex];

        wordSep = [NSCharacterSet whitespaceAndNewlineCharacterSet];
        if ([wordSep characterIsMember:ch])
            return YES;

        wordSep = [NSCharacterSet punctuationCharacterSet];
        if ([wordSep characterIsMember:ch])
            return YES;
    }

    return NO;
}

- (BOOL)isStartOfWordAtIndex:(unsigned)anIndex;
{
    if (anIndex == 0)
        return YES;
    else
    {
        anIndex -= 1;  // get the character before this index
        if (anIndex >=0 && anIndex < [self length])
        {
            NSCharacterSet *wordSep;
            unichar ch;

            ch = [self characterAtIndex:anIndex];

            wordSep = [NSCharacterSet whitespaceAndNewlineCharacterSet];
            if ([wordSep characterIsMember:ch])
                return YES;

            wordSep = [NSCharacterSet punctuationCharacterSet];
            if ([wordSep characterIsMember:ch])
                return YES;
        }
    }

    return NO;
}

- (NSString*)stringByTruncatingToLength:(unsigned)length;
{
    NSString* result = self;

    if ([self length] > length)
    {
        int segmentLen = (length/2) - 2;

        result = [self substringToIndex:segmentLen];
        result = [result stringByAppendingString:@"..."];
        result = [result stringByAppendingString:[self substringFromIndex:([self length] - segmentLen)]];
    }

    return result;
}

#define kEncryptionKey 1

- (NSString*)stringByEncryptingString;
{
    int i, cnt=[self length];
    NSMutableString *result = [NSMutableString string];

    for (i=0;i<cnt;i++)
    {
        unichar aChar = [self characterAtIndex:i];

        [result appendCharacter:aChar + kEncryptionKey];
    }

    return result;
}

- (NSString*)stringByDecryptingString;
{
    int i, cnt=[self length];
    NSMutableString *result = [NSMutableString string];

    for (i=0;i<cnt;i++)
    {
        unichar aChar = [self characterAtIndex:i];

        [result appendCharacter:aChar - kEncryptionKey];
    }

    return result;
}

- (BOOL)FSRef:(FSRef*)fsRef createFileIfNecessary:(BOOL)createFile;
{
    NSFileManager* fileManager = [NSFileManager defaultManager];
    CFURLRef urlRef;
    Boolean gotFSRef;

    // Check whether the file exists already.  If not, create an empty file if requested.
    if (![fileManager fileExistsAtPath:self])
    {
        if (createFile)
        {
            if (![@"" writeToFile:self atomically:YES])
                return NO;
        }
        else
            return NO;
    }

    // Create a CFURL with the specified POSIX path.
    urlRef = CFURLCreateWithFileSystemPath( kCFAllocatorDefault,
                                            (CFStringRef) self,
                                            kCFURLPOSIXPathStyle,
                                            FALSE /* isDirectory */ );
    if (urlRef == NULL)
        return NO;

    gotFSRef = CFURLGetFSRef(urlRef, fsRef);
    CFRelease(urlRef);

    if (!gotFSRef)
        return NO;

    return YES;
}

- (BOOL)FSSpec:(FSSpec*)fsSpec createFileIfNecessary:(BOOL)createFile;
{
    FSRef fsRef;

    if (![self FSRef:&fsRef createFileIfNecessary:createFile])
        return NO;

    if (FSGetCatalogInfo( &fsRef,
                          kFSCatInfoNone,
                          NULL,
                          NULL,
                          fsSpec,
                          NULL ) != noErr)
    {
        return NO;
    }

    return YES;
}

// doesn't allow extensions with spaces
- (NSString*)strictPathExtension;
{
    NSString* ext = [self pathExtension];
    NSRange spaceRange;
    
    if ([ext length])
    {
        // search for a space
        spaceRange=[ext rangeOfString:@" " options:NSLiteralSearch];
        if (spaceRange.location != NSNotFound)
            return @"";
    }
    
    return ext;    
}

- (NSString*)strictStringByDeletingPathExtension;
{
    NSString* ext = [self strictPathExtension];
    
    // if we don't find an extension, don't call stringByDeletingPathExtension
    if (![ext length])
        return self;
    
    return [self stringByDeletingPathExtension];
}


@end

// ================================================================================================

@implementation NSMutableString(utils)

- (void)replace:(NSString *)value with:(NSString *)newValue;
{    
    [self replaceOccurrencesOfString:value withString:newValue options:NSLiteralSearch range:NSMakeRange(0, [self length])];
}

@end

