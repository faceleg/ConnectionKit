//
//  SVDocumentInspector.m
//  Sandvox
//
//  Created by Dan Wood on 2/5/10.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVDocumentInspector.h"

#import "KTDocument.h"
#import "KTMaster.h"

#import "Registration.h"
#import "KSLicensedAppDelegate.h"

#import "KSCollectionController.h"

#import "NSString+Karelia.h"


static NSString *sLanguageObservationContext = @"SVDocumentInspectorLanguageObservation";


@implementation SVDocumentInspector

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil;
{
    [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    
    [self addObserver:self
           forKeyPath:@"inspectedObjectsController.selection.master.language"
              options:0
              context:sLanguageObservationContext];
    
    return self;
}

- (void)dealloc
{
    [self removeObserver:self
              forKeyPath:@"inspectedObjectsController.selection.master.language"];
    
	[[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}


- (void)updateProView:(NSNotification *)aNotif
{
	BOOL licensedForPro =  (nil != gRegistrationString) && gIsPro;
	
	[oProBadge setHidden:licensedForPro];	// only show it if we are not PRO
    [oProButton setEnabled:licensedForPro];	// If we had other stuff here we'd need to enable pieces
}

- (void)loadView;
{
    [super loadView];
    
    
    // Populate languages popup
    NSArray *languages = [self languages];
    NSEnumerator *theEnum = [languages objectEnumerator];
    id object;
    int theIndex = 0;
    
    while (nil != (object = [theEnum nextObject]) )
    {
        NSString *ownName = [[object objectForKey:@"Name"] stringByTrimmingWhitespace];
        // not using
        //			NSString *englishName = [[object objectForKey:@"Eng"]
        //				trim];
        //			NSString *charset = [[object objectForKey:@"Charset"] 
        //				trim];
        NSString *code = [[object objectForKey:@"Code"] 
                          stringByTrimmingWhitespace];
        [oLanguagePopup insertItemWithTitle:ownName atIndex:theIndex];
        NSMenuItem *thisItem = [oLanguagePopup itemAtIndex:theIndex];
        [thisItem setRepresentedObject:code];
        theIndex++;
    }
 
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(updateProView:)
												 name:kKSLicenseStatusChangeNotification
											   object:nil];
	[self updateProView:nil];	// update them now
	
}

//  check representedObject property that's the document.  windowForSheet -- to forward the message....

- (IBAction)configureComments:(id)sender;
{
	KTDocument *doc = [self representedObject];
	NSLog(@"configureComments %@", doc);
	
}

- (IBAction)chooseFavicon:(id)sender;
{
	KTDocument *document = [self representedObject];
    NSOpenPanel *panel = [document makeChooseDialog];
    
    if ([panel runModal] == NSFileHandlingPanelOKButton)
    {
        NSURL *URL = [panel URL];
        
        KTMaster *master = [[[self inspectedObjectsController] selection] valueForKey:@"master"];
        [master setFaviconWithContentsOfURL:URL];
    }
}

- (IBAction)chooseBanner:(id)sender;
{
	KTDocument *document = [self representedObject];
    NSOpenPanel *panel = [document makeChooseDialog];
    
    if ([panel runModal] == NSFileHandlingPanelOKButton)
    {
        NSURL *URL = [panel URL];
        
        KTMaster *master = [[[self inspectedObjectsController] selection] valueForKey:@"master"];
        [master setBannerWithContentsOfURL:URL];
    }
}

#pragma mark Info Tab

- (void)refresh;
{
    [super refresh];
}
    
- (NSArray *)languages
{
    static NSArray *result;
    
    if (!result)
    {
        NSString *path = [[NSBundle mainBundle] pathForResource:@"Languages" ofType:@"plist"];
        if (path)
        {
            result = [[NSArray alloc] initWithContentsOfFile:path];
        }
    }
    
    return result;
}

- (IBAction)languageChosen:(id)sender;
{
	BOOL isOther = [[sender selectedItem] tag] < 0;
	[oLanguageCodeField setEnabled:isOther];
	
	NSString *languageCode = [[sender selectedItem] representedObject];
	[(NSObject *)[self inspectedObjectsController] setValue:languageCode forKeyPath:@"selection.master.language"];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == sLanguageObservationContext)
    {
        NSString *languageCode = [object valueForKeyPath:keyPath];
        NSInteger theIndex = [oLanguagePopup indexOfItemWithRepresentedObject:languageCode];
        BOOL otherLanguage = (theIndex < 0);
        [oLanguageCodeField setEnabled:otherLanguage];
        if (otherLanguage)
        {
            theIndex = [oLanguagePopup indexOfItemWithTag:-1];
        }
        [oLanguagePopup selectItemAtIndex:theIndex];
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end
