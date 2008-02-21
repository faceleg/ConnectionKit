//
//  KTMediaContainer+Pasteboard.m
//  Marvel
//
//  Created by Mike on 29/12/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import "KTMediaContainer+Pasteboard.h"

#import "KTAbstractMediaFile.h"
#import "KTPasteboardArchiving.h"

#import "BDAlias.h"


@implementation KTMediaContainer (Pasteboard)

- (id <NSCoding>)pasteboardRepresentation
{
	BDAlias *alias = [BDAlias aliasWithPath:[[self file] currentPath]];
	return [[[KTMediaContainerPasteboardRepresentation alloc] initWithAlias:alias] autorelease];
}

- (id <NSCoding>)IDOnlyPasteboardRepresentation
{
	return [self pasteboardRepresentation];
}

@end


@implementation KTMediaContainerPasteboardRepresentation

- (id)initWithAlias:(BDAlias *)alias
{
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
