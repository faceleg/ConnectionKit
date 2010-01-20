//
//  KTMediaContainer+Pasteboard.m
//  Marvel
//
//  Created by Mike on 29/12/2007.
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//

#import "KTMediaContainer+Pasteboard.h"

#import "KTInDocumentMediaFile.h"
#import "KTExternalMediaFile.h"
#import "KTPasteboardArchiving.h"

#import "BDAlias.h"


@implementation KTMediaContainer (Pasteboard)

- (id <NSCoding>)pasteboardRepresentation
{
	id result = [[self file] pasteboardRepresentation];
    return result;
}

- (id <NSCoding>)IDOnlyPasteboardRepresentation
{
	return [self pasteboardRepresentation];
}

@end


@implementation KTInDocumentMediaFile (Pasteboard)

- (id <NSCoding>)pasteboardRepresentation
{
	NSString *path = [self currentPath];
    OBASSERT(path);
    BDAlias *alias = [BDAlias aliasWithPath:path];
	OBASSERT(alias);
	return [[[KTMediaContainerPasteboardRepresentation alloc] initWithAlias:alias] autorelease];
}

@end


@implementation KTExternalMediaFile (Pasteboard)

- (id <NSCoding>)pasteboardRepresentation
{
	BDAlias *alias = [self alias];
	OBASSERT(alias);
	return [[[KTMediaContainerPasteboardRepresentation alloc] initWithAlias:alias] autorelease];
}

@end


#pragma mark -


@implementation KTMediaContainerPasteboardRepresentation

- (id)initWithAlias:(BDAlias *)alias
{
	OBASSERT(alias);
	[super init];
	myAlias = [alias retain];
	return self;
}

- (void)dealloc
{	
	[myAlias release];
	[super dealloc];
}

- (BDAlias *)alias { return myAlias; }

- (id)initWithCoder:(NSCoder *)decoder
{
	BDAlias *alias = [BDAlias aliasWithData:[decoder decodeObjectForKey:@"alias"]];
	return [self initWithAlias:alias];
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeObject:[[self alias] aliasData] forKey:@"alias"];
}

@end
