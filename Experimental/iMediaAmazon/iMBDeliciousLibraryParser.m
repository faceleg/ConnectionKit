//
//  iMBDeliciousLibraryParser.m
//  iMediaAmazon
//
//  Created by Dan Wood on 4/5/07.
//  Copyright 2007-2011 Karelia Software. All rights reserved.
//

#import "iMBDeliciousLibraryParser.h"


@implementation iMBDeliciousLibraryParser

+ (void)load	// to register
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[iMediaBrowser registerParser:[self class] forMediaType:@"amazon"];
	[pool release];
}

- (id)init
{
	NSArray *appSupport = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,NSUserDomainMask,YES);
	NSString *libraryPath = [[appSupport objectAtIndex:0] stringByAppendingPathComponent:@"Delicious Library/Library Media Data.xml"];
	if (self = [super initWithContentsOfFile:libraryPath])
	{

	}
	return self;
}

- (iMBLibraryNode *)parseDatabase
{
	NSError *err = nil;
	NSFileManager *fm = [NSFileManager defaultManager];
	if (![fm fileExistsAtPath:[self databasePath]])
	{
		return nil;
	}
	NSXMLDocument *xml = [[[NSXMLDocument alloc] initWithContentsOfURL:[NSURL fileURLWithPath:[self databasePath]]
															   options:NSXMLDocumentValidate
																 error:&err] autorelease];

	if (err)
	{
		NSLog(@"%@", [err localizedDescription]);
	}
	if (!xml)
	{
		return nil;
	}
	
    // Create the root node
	iMBLibraryNode *root = [[[iMBLibraryNode alloc] init] autorelease];
	[root setName:LocalizedStringInThisBundle(@"Delicious Library", @"Application 'Delicious Library' contents in the Amazon source list")];
	[root setIconName:@"com.delicious-monster.library:"];
	[root setFilterDuplicateKey:@"ImagePath" forAttributeKey:@"Movies"];
	
    // Create default subnodes
	iMBLibraryNode *bookLib	 = [[[iMBLibraryNode alloc] init] autorelease];
	iMBLibraryNode *movieLib = [[[iMBLibraryNode alloc] init] autorelease];
	iMBLibraryNode *musicLib = [[[iMBLibraryNode alloc] init] autorelease];
	iMBLibraryNode *gameLib = [[[iMBLibraryNode alloc] init] autorelease];

	[bookLib setName:LocalizedStringInThisBundle(@"Books", @"Books as titled in 'Delicious Library' source list")];
	[bookLib setIconName:@"com.delicious-monster.library:books_sm"];
	
	[movieLib setName:LocalizedStringInThisBundle(@"Movies", @"Movies as titled in 'Delicious Library' source list")];
	[movieLib setIconName:@"com.delicious-monster.library:movies_sm"];

	[musicLib setName:LocalizedStringInThisBundle(@"Music", @"Movies as titled in 'Delicious Library' source list")];
	[musicLib setIconName:@"com.delicious-monster.library:music_sm"];

	[gameLib setName:LocalizedStringInThisBundle(@"Games", @"Games as titled in 'Delicious Library' source list")];
	[gameLib setIconName:@"com.delicious-monster.library:games_sm"];


	NSXMLElement *rootXML = [xml rootElement];
	NSArray *items = [rootXML nodesForXPath:@"/library/items" error:&err];	// get to the items node
	if ([items count])
	{
		items = [[items objectAtIndex:0] children];	// now get all the children of this, which have different types
	}
	if (err) NSLog(@"%@", [err localizedDescription]);
	
	NSEnumerator *e = [items objectEnumerator];
	NSXMLElement *cur;
		
	BOOL hasItems = NO;
	NSMutableArray *booksArray = [NSMutableArray array];
	NSMutableArray *moviesArray= [NSMutableArray array];
	NSMutableArray *musicArray = [NSMutableArray array];
	NSMutableArray *gamesArray = [NSMutableArray array];
	
	while (cur = [e nextObject])
	{
		NSString *name = [cur localName];

		NSMutableArray *libToAddTo = nil;
		
		if		([name isEqualToString:@"book"])	libToAddTo = booksArray;
		else if	([name isEqualToString:@"movie"])	libToAddTo = moviesArray;
		else if	([name isEqualToString:@"music"])	libToAddTo = musicArray;
		else if	([name isEqualToString:@"game"])	libToAddTo = gamesArray;

		NSMutableDictionary *item = [NSMutableDictionary dictionary];

		NSString *asin = [[cur attributeForName:@"asin"] stringValue];
		
		if (asin)	// only add if there is an ASIN!
		{
			hasItems = YES;
			[item setObject:asin forKey:@"asin"];

			NSString *title = [[cur attributeForName:@"title"] stringValue];
			if (title) [item setObject:title forKey:@"name"];
			
			
			NSString *creator = [[cur attributeForName:@"author"] stringValue];
			if (!creator) creator = [[cur attributeForName:@"artist"] stringValue];
			if (!creator) creator = [[cur attributeForName:@"director"] stringValue];
			if (creator) [item setObject:creator forKey:@"creator"];
			
			[libToAddTo addObject:item];
		}
	}
	
	if (hasItems)
	{
		int idx = 0;
		if ([booksArray count])
		{
			[bookLib setAttribute:booksArray forKey:@"newReleases"];
			[root insertItem:bookLib atIndex:idx];
			idx++;
		}
		if ([moviesArray count])
		{
			[movieLib setAttribute:moviesArray forKey:@"newReleases"];
			[root insertItem:movieLib atIndex:idx];
			idx++;
		}
		if ([musicArray count])
		{
			[musicLib setAttribute:musicArray forKey:@"newReleases"];
			[root insertItem:musicLib atIndex:idx];
			idx++;
		}
		if ([gamesArray count])
		{
			[gameLib setAttribute:gamesArray forKey:@"newReleases"];
			[root insertItem:gameLib atIndex:idx];
			idx++;
		}
		return root;
	}
	return nil;
}

@end
