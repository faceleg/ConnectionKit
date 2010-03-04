// 
//  SVTextBox.m
//  Sandvox
//
//  Created by Mike on 10/02/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVTextBox.h"

#import "SVRichText.h"
#import "SVHTMLTemplateParser.h"
#import "SVTemplate.h"


@interface SVTextBox ()
@property(nonatomic, retain, readwrite) SVRichText *body;
@end


#pragma mark -


@implementation SVTextBox 

+ (SVTextBox *)insertNewTextBoxIntoManagedObjectContext:(NSManagedObjectContext *)moc;
{
	OBPRECONDITION(moc);
	
	
    // Create the pagelet
	SVTextBox *result = [NSEntityDescription insertNewObjectForEntityForName:@"TextBox"
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
    [self setBody:[SVRichText insertPageletBodyIntoManagedObjectContext:[self managedObjectContext]]];
}

#pragma mark HTML

- (void)writeBody;
{
    static SVTemplate *sBodyTemplate;
    if (!sBodyTemplate)
    {
        sBodyTemplate = [[SVTemplate templateNamed:@"TextBoxBodyTemplate.html"] retain];
    }
    
    SVHTMLTemplateParser *parser =
    [[SVHTMLTemplateParser alloc] initWithTemplate:[sBodyTemplate templateString]
                                         component:self];
    
    [parser parse];
    [parser release];
}

@end
