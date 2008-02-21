//
//  NSString+KTExtensions.m
//  KTComponents
//
//  Copyright (c) 2004-2005 Biophony LLC. All rights reserved.
//

#import "NSString+Karelia.h"

#import "KT.h"
#import "NSCharacterSet+Karelia.h"
#import "NSData+Karelia.h"
#import "NSString-Utilities.h"

@implementation NSString ( KTExtensions )






/*!	Figures out relative path, from otherPath to this
 */
- (NSString *)pathRelativeTo:(NSString *)otherPath
{
	// SANDVOX ONLY -- if we have a special page ID, then don't try to make relative
	if (NSNotFound != [otherPath rangeOfString:kKTPageIDDesignator].location)
	{
		return self;
	}	
	
	// General Purpose
	
	NSString *commonPrefix = [self commonPrefixWithString:otherPath options:NSLiteralSearch];
	// Make sure common prefix ends with a / ... if not, back up to the previous /
	if ([commonPrefix isEqualToString:@""])
	{
		return self;
	}
	if (![commonPrefix hasSuffix:@"/"])
	{
		NSRange whereSlash = [commonPrefix rangeOfString:@"/" options:NSLiteralSearch|NSBackwardsSearch];
		if (NSNotFound == whereSlash.location)
		{
			return self;	// nothing in common, return
		}
		
		// Fix commonPrefix so it ends in /
		commonPrefix = [commonPrefix substringToIndex:NSMaxRange(whereSlash)];
	}
	
	NSString *myDifferingPath = [self substringFromIndex:[commonPrefix length]];
	NSString *otherDifferingPath = [otherPath substringFromIndex:[commonPrefix length]];
	
	NSMutableString *buf = [NSMutableString string];
	unsigned int i;
	
	// generate hops up from other to the common place
	NSArray *hopsUpArray = [otherDifferingPath pathComponents];
	unsigned int hopsUp = MAX(0,(int)[hopsUpArray count] - 1);
	for (i = 0 ; i < hopsUp ; i++ )
	{
		[buf appendString:@"../"];
	}
	
	// the rest is the relative path to me
	[buf appendString:myDifferingPath];
	
	if ([buf isEqualToString:@""])	
	{
		if ([self hasSuffix:@"/"])
		{
			[buf appendString:@"./"];	// if our relative link is to the top, then replace with ./
		}
		else	// link to yourself; give us just the file name
		{
			[buf appendString:[self lastPathComponent]];
		}
	}
	NSString *result = [NSString stringWithString:buf];
	return result;
}


//- (NSString *)pathRelativeToRoot
//{
//    // remove everything up to, but not including, Source
//    // so /Users/ttalbot/Sites/BigSite.site/Contents/Source/whatever becomes Source/whatever
//    NSMutableArray *components = [NSMutableArray arrayWithArray:[self pathComponents]];
//    NSEnumerator *componentsEnumerator = [components objectEnumerator];
//    NSString *component;
//    
//    while ( component = [componentsEnumerator nextObject] ) {
//        if ( ![component isEqualToString:@"Source"] ) {
//            [components removeObject:component];
//        }
//        else {
//            break;
//        }
//    }
//    return [NSString pathWithComponents:components];
//}

@end

