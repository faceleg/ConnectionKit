//
//  KTParsedKeyPath.m
//  Marvel
//
//  Created by Mike on 22/09/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import "KTParsedKeyPath.h"


@implementation KTParsedKeyPath

- (id)initWithKeyPath:(NSString *)keyPath ofObject:(NSObject *)object
{
	[super init];
	
	myObject = [object retain];
	myKeyPath = [keyPath copy];
	
	return self;
}

- (void)dealloc
{
	[myObject release];
	[myKeyPath release];
	
	[super dealloc];
}

- (unsigned)hash { return [[self keyPath] hash]; }

- (BOOL)isEqual:(id)anObject
{
	BOOL result = NO;
	
	if ([anObject isKindOfClass:[KTParsedKeyPath class]])
	{
		KTParsedKeyPath *aKeyPath = anObject;
		
		result = ([[aKeyPath keyPath] isEqual:[self keyPath]] &&
				  [[aKeyPath parsedObject] isEqual:[self parsedObject]]);
	}
	else
	{
		result = [super isEqual:anObject];
	}
	
	return result;
}

- (NSString *)keyPath { return myKeyPath; }

- (NSObject	*)parsedObject { return myObject; }

- (NSString *)description
{
	return [NSString stringWithFormat:@"%@ of %p", [self keyPath], [self parsedObject]];
}

@end
