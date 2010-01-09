//
//  SVLink.h
//  Sandvox
//
//  Created by Mike on 09/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <CoreData/CoreData.h>


@class KTAbstractPage;
@class SVBodyParagraph;


@interface SVLink :  NSManagedObject  
{
}

@property (nonatomic, retain) NSNumber * length;
@property (nonatomic, retain) NSString * URLString;
@property (nonatomic, retain) NSNumber * location;
@property (nonatomic, retain) SVBodyParagraph * paragraph;
@property (nonatomic, retain) KTAbstractPage * page;

@end



