// 
//  SVTextBox.m
//  Sandvox
//
//  Created by Mike on 10/02/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVTextBox.h"

#import "SVBody.h"


@interface SVTextBox ()
@property(nonatomic, retain, readwrite) SVBody *body;
@end


#pragma mark -


@implementation SVTextBox 

+ (SVTextBox *)insertNewTextBoxIntoManagedObjectContext:(NSManagedObjectContext *)moc;
{
	OBPRECONDITION(moc);
	
	
    // Create the pagelet
	SVPagelet *result = [NSEntityDescription insertNewObjectForEntityForName:@"TextBox"
													  inManagedObjectContext:moc];
	OBASSERT(result);
	
    
	return result;
}

#pragma mark Body Text

@dynamic body;

- (void)awakeFromInsert
{
    [super awakeFromInsert];
    
    
    // Create corresponding body text
    [self setBody:[SVBody insertPageletBodyIntoManagedObjectContext:[self managedObjectContext]]];
}

@end
