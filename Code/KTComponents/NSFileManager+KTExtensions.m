//
//  NSFileManager+KTExtensions.m
//  KTComponents
//
//  Created by Terrence Talbot on 4/16/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "NSFileManager+KTExtensions.h"

#import "Debug.h"


@implementation NSFileManager ( KTExtensions )

- (BOOL)createDirectoryPath:(NSString *)path attributes:(NSDictionary *)attributes
{
	if ( ![path isAbsolutePath] )
	{
		[NSException raise:@"KTFileManagerException" format:@"createDirectoryPath:attributes: path not absolute:%@", path];
		return NO;
	}
	
	NSString *thePath = @"";
	BOOL result = YES;

    NSEnumerator *enumerator = [[path pathComponents] objectEnumerator];
    NSString *component;
    while ( component = [enumerator nextObject] )
    {
        thePath = [thePath stringByAppendingPathComponent:component];
        if ( ![[NSFileManager defaultManager] fileExistsAtPath:thePath] )
		{
			result = result && [[NSFileManager defaultManager] createDirectoryAtPath:thePath 
																		  attributes:attributes];
			if ( NO == result )
			{
				[NSException raise:@"KTFileManagerException" format:@"createDirectory:attributes: failed at path: %@", path];
				return NO;
			}
		}
    }
		
    return ( (YES == result) && [[NSFileManager defaultManager] fileExistsAtPath:path] );
}

// Pass in nil for aName if we want to use ID
- (NSData *)readFromResourceFileAtPath:(NSString *)aPath type:(ResType) aType named:(NSString *)aName id:(short int)anID
{
	short int	fileRef = 0;
	NSData *result = nil;
	@try
	{
		FSRef theFSRef;
		if (noErr == FSPathMakeRef((const UInt8 *)[aPath UTF8String], &theFSRef, NULL ))
		{
			fileRef = FSOpenResFile(&theFSRef, fsRdPerm);
			if (noErr == ResError())
			{
				Handle		theResHandle = NULL;
				short int	thePreviousRefNum = CurResFile();	// save current resource
				Str255		thePName;
				
				UseResFile(fileRef);    		// set this resource to be current
				
				if (noErr ==  ResError())
				{
					if (aName)	// use name
					{
						Str255 pString;
						// Create pascal string -- assume MacRoman encoding for resource names?
						BOOL success = CFStringGetPascalString((CFStringRef)aName,
															   pString,
															   [aName length],
															   kCFStringEncodingMacRomanLatin1);
						if (success)
						{
							theResHandle = Get1NamedResource( aType, thePName );
						}
					}
					else	// use ID
					{
						theResHandle = Get1Resource( aType, anID );
					}	
					
					if (theResHandle && noErr == ResError())
					{
						// Wow, this is a trip down memory lane for Dan!
						HLock(theResHandle);
						result = [NSData dataWithBytes:*theResHandle length:GetHandleSize(theResHandle)];
						HUnlock(theResHandle);
						ReleaseResource(theResHandle);
					}
				}
				UseResFile( thePreviousRefNum );     		// reset back to resource previously set
			}
		}
	}
	@finally
	{
		if( fileRef > 0)
		{
			CloseResFile(fileRef);
		}
	}
	return result;
}

/*!	If the file at the given path is an alias file, this will resolve this.  Useful before getting
	files from user operations such as dragging in a file.  Now they can drag in an alias file.

	I don't think this will do anything with an alias in the middle of the path representing a folder,
	but I don't think that would be valid path anyhow.

*/
- (NSString *)resolvedAliasPath:(NSString *)aPath
{
	NSString *result = aPath;
	FSRef theRef;
	Boolean theIsTargetFolder, theWasAliased;

	if (noErr == FSPathMakeRef((const UInt8 *)[aPath UTF8String], &theRef, &theIsTargetFolder))
	{
		if (noErr == FSResolveAliasFile (&theRef, YES, &theIsTargetFolder, &theWasAliased ) )
		{
			if (theWasAliased)
			{
				UInt8 newPath[PATH_MAX + 1];        // plus 1 for \0 terminator
				if (noErr ==  FSRefMakePath(&theRef, newPath, PATH_MAX ))
				{
					result = [NSString stringWithUTF8String:(const char *)newPath];
				}
			}
		}
	}
	return result;
}

- (NSNumber *)sizeOfFileAtPath:(NSString *)aPath
{
    NSNumber *result = nil;
    
    NSDictionary *fileAttributes = [self fileAttributesAtPath:aPath traverseLink:YES];
    if ( nil != fileAttributes )
    {
        result = [fileAttributes objectForKey:NSFileSize];
    }
    
    return result;
}

- (BOOL)setExtensionHiddenAtPath:(NSString *)aPath
{
	return [self changeFileAttributes:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:NSFileExtensionHidden]
							   atPath:aPath];
}

/*	Pass in the path you'd like. e.g. /Users/Bob/image.jpg
 *	If the path doesn't exist, we return it as the result.
 *	If it does already exist a new path is constructed. e.g. /Users/Bob/image-2.jpg
 *	and that is tested. The cycle repeats until a unused path is found
 */
- (NSString *)uniqueFilenameAtPath:(NSString *)startingPath
{
	NSString *result = startingPath;
	
	NSString *directory = [startingPath stringByDeletingLastPathComponent];
	NSString *fileName = [[startingPath lastPathComponent] stringByDeletingPathExtension];
	NSString *extension = [startingPath pathExtension];
	unsigned count = 1;
	
	// Loop through, only ending when the file doesn't exist
	while ([self fileExistsAtPath:result])
	{
		count++;
		NSString *aFileName = [NSString stringWithFormat:@"%@-%u", fileName, count];
		result = [directory stringByAppendingPathComponent:[aFileName stringByAppendingPathExtension:extension]];
	}
	
	return [result lastPathComponent];
}

@end
