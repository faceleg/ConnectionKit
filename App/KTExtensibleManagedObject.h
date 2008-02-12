//
//  KTExtensibleManagedObject.h
//  Marvel
//
//  Created by Mike on 25/08/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//
//	A special kind of managed object that allows you to use -valueForKey: and
//	-setValueForKey: using any key. If the object does not normally accept this
//	key, it is stored internally in a dictionary and then archived as data.


#import <Cocoa/Cocoa.h>
#import "KTManagedObject.h"


@interface KTExtensibleManagedObject : KTManagedObject
{
	NSMutableDictionary	*myValues;
}

+ (NSString *)extensiblePropertiesDataKey;

- (NSDictionary *)extensiblePropertyValues;

/*!	These two methods are called by KTExtensibleManagedObject when archiving or unarchiving
 *	the dictionary it uses in-memory. You can override them in a subclass to tweak the
 *	behaviour. e.g. To use an encoding method other than NSKeyedArchiver.
 */
- (NSMutableDictionary *)unarchiveExtensiblePropertiesDictionary:(NSData *)propertiesData;
- (NSData *)archiveExtensiblePropertiesDictionary:(NSDictionary *)properties;

@end
