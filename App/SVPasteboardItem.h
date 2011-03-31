//
//  SVPasteboardItem.h
//  Sandvox
//
//  Created by Mike on 08/10/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

//  This header should be well commented as to its functionality. Further information can be found at 
//  http://docs.karelia.com/z/Sandvox_Developers_Guide.html


#import <Cocoa/Cocoa.h>


@protocol SVPasteboardItem <NSObject>

// These methods try their best to infer the info from pasteboard.
- (NSString *)title;
- (NSURL *)URL;
- (NSDictionary *)metadata;

/* Returns an array of UTI strings of the data types supported by the receiver.
 */
- (NSArray *)types;

/* Given an array of types, will return the first type contained in the pasteboard item, according to the sender's ordering of types.  It will check for UTI conformance of the requested types, preferring an exact match to conformance.
 */
- (NSString *)availableTypeFromArray:(NSArray *)types;

/* Returns a value for the provided UTI type string.
 */
- (NSData *)dataForType:(NSString *)type;
- (NSString *)stringForType:(NSString *)type;
- (id)propertyListForType:(NSString *)type;

@end
