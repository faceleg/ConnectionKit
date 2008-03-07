//
//  KTDocument+Bindings.m
//  Marvel
//
//  Copyright (c) 2004-2005 Biophony, LLC. All rights reserved.
//

/*
PURPOSE OF THIS CLASS/CATEGORY:
	- Observe state of showing private properties in inspector
	- Define property methods so that properties will be checked when asking for attributes

TAXONOMY AND RELATIONSHIP TO OTHER CLASSES:
	x

IMPLEMENTATION NOTES & CAUTIONS:
	KTDocument is the last link along a "chain" of properties.  This allows us to ask for a property
	of an element or page; if not found there, it looks in its enclosing folders; finally the document's
	properties are checked.

TO DO:
	x

 */

#import "KTDocument.h"
#import "KT.h"
#import "KTAppDelegate.h"
#import "Debug.h"

@implementation KTDocument ( Bindings )

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
	{
		LOG((@"observeValueForKeyPath: %@", keyPath));
		LOG((@"                object: %@", object));
		LOG((@"                change: %@", [change description]));
	}
}

/*!	Overriding valueForUndefinedKey allows HTML to ask for an ad-hoc property from the user defaults
*/
- (id)valueForUndefinedKey:(NSString *)aKey
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	id result = [defaults objectForKey:aKey];
	if (nil == result)
	{
		LOG((@"asking document valueForUndefinedKey: %@ -- nil results returned from defaults", aKey));
	}
	return result;
}

@end

