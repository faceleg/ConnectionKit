//
//  KTArchivedMediaContainer.h
//  Marvel
//
//  Created by Mike on 14/12/2007.
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "KTAbstractPage.h"
@class KTDocument;

@interface KTExtensiblePluginPropertiesArchivedObject : NSObject <NSCoding>
{
	NSString *myClassName;
	NSString *myEntityName;
	NSString *myObjectIdentifier;
}

- (id)initWithObject:(NSManagedObject <KTExtensiblePluginPropertiesArchiving> *)anObject;
- (NSManagedObject *)realObjectInDocument:(KTDocument *)document;
@end
