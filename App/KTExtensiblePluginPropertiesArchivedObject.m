//
//  KTArchivedMediaContainer.m
//  Marvel
//
//  Created by Mike on 14/12/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import "KTExtensiblePluginPropertiesArchivedObject.h"


@implementation KTExtensiblePluginPropertiesArchivedObject

- (id)initWithClassName:(NSString *)className entityName:(NSString *)entityName ID:(NSString *)ID
{
    [super init];
    
    myClassName = [className copy];
	myEntityName = [entityName copy];
	myObjectIdentifier = [ID copy];
	
	return self;
}

- (id)initWithObject:(NSManagedObject <KTExtensiblePluginPropertiesArchiving> *)anObject
{
	[self initWithClassName:NSStringFromClass([anObject class])
                 entityName:[[anObject entity] name]
                         ID:[anObject archiveIdentifier]];
	
	return self;
}

- (id)initWithCoder:(NSCoder *)decoder
{
	[super init];
	
	myClassName = [[decoder decodeObjectForKey:@"class"] copy];
	myEntityName = [[(NSKeyedUnarchiver *)decoder decodeObjectForKey:@"entityName"] copy];
	myObjectIdentifier = [[(NSKeyedUnarchiver *)decoder decodeObjectForKey:@"objectIdentifier"] copy];
	
	return self;
}

- (void)dealloc
{
	[myClassName release];
	[myEntityName release];
	[myObjectIdentifier release];
	
	[super dealloc];
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeObject:myClassName forKey:@"class"];
	[encoder encodeObject:myEntityName forKey:@"entityName"];
	[encoder encodeObject:myObjectIdentifier forKey:@"objectIdentifier"];
}

- (NSManagedObject *)realObjectInDocument:(KTDocument *)document;
{
	Class objectClass = NSClassFromString(myClassName);
	NSAssert1(objectClass, @"No class for class name '%@'", myClassName);
	
	NSManagedObject *result = [objectClass objectWithArchivedIdentifier:myObjectIdentifier
															 inDocument:document];
															 
	
	return result;
}

@end
