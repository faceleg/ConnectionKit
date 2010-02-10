//
//  SVTextBox.h
//  Sandvox
//
//  Created by Mike on 10/02/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <CoreData/CoreData.h>
#import "SVPagelet.h"

@class SVBody;

@interface SVTextBox :  SVPagelet  

+ (SVTextBox *)insertNewTextBoxIntoManagedObjectContext:(NSManagedObjectContext *)context;

#pragma mark Body Text
@property(nonatomic, retain, readonly) SVBody *body;


@end



