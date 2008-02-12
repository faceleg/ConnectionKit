#import <Foundation/Foundation.h>

@interface NSString (Utilities)
+ stringWithFileSystemRepresentation:(const char*)path;
+ (NSString*)stringWithPString:(Str255)pString;

- (void)getPString:(Str255)outString;

// These two routine will convert : to / and / to : so if they are paths
+ (NSString*)stringWithHFSUniStr255:(const HFSUniStr255*)hfsString;
- (void)getHFSUniStr255:(HFSUniStr255*)hfsString;

- (NSString*)stringByReplacing:(NSString *)value with:(NSString *)newValue;
- (NSString*)stringByReplacingValuesInArray:(NSArray *)values withValuesInArray:(NSArray *)newValues;
- (NSString*)stringByDeletingSuffix:(NSString *)suffix;
- (NSString*)stringWithShellCharactersQuoted;
- (BOOL)stringContainsValueFromArray:(NSArray *)theValues;
- (BOOL)isEqualToStringCaseInsensitive:(NSString *)str;

- (NSArray*)linesFromString:(NSString**)outRemainder;
- (NSString*)getFirstLine;
- (NSString*)stringWithRegularExpressionCharactersQuoted;

    // converts a POSIX path to an HFS path
- (NSString*)HFSPath;
    // converts a HFS path to a POSIX path
- (NSString*)POSIXPath;

- (BOOL)isEndOfWordAtIndex:(unsigned)index;
- (BOOL)isStartOfWordAtIndex:(unsigned)index;

- (NSString*)stringByTruncatingToLength:(unsigned)length;

- (NSString*)stringByDecryptingString;
- (NSString*)stringByEncryptingString;

- (BOOL)FSRef:(FSRef*)fsRef createFileIfNecessary:(BOOL)createFile;
- (BOOL)FSSpec:(FSSpec*)fsSpec createFileIfNecessary:(BOOL)createFile;

- (NSString*)URLEncodedString;

// excludes extensions with spaces
- (NSString*)strictPathExtension;
- (NSString*)strictStringByDeletingPathExtension;

@end

// =======================================================================================

@interface NSMutableString(utils)
- (void)replace:(NSString *)value with:(NSString *)newValue;
@end

