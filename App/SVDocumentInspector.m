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
	BOOL licensed =  (nil != gRegistrationString);
	BOOL licensedForPro =  (nil != gRegistrationString) && gIsPro;
	
	[oProBadge setHidden:licensed];	// only show "Pro" badge if we are unregistered
	// Make the button enabled if we are a demo, or a pro license
    [oProButton setHidden:(licensed && !licensedForPro)]; // If we had other stuff here we'd need to enable pieces
}

- (void)viewDidLoad;
{
    // Populate languages popup. Must happen before -refresh (which super will call)
    NSArray *languages = [self languages];
    int theIndex = 0;
    
    for (id object in languages)
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
    
    
    // Now we're ready to call super
	[super viewDidLoad];
    
    
    // Bind banner type
    [oBannerPickerController bind:@"bannerType" toObject:self withKeyPath:@"inspectedObjectsController.selection.master.bannerType" options:nil];
    
    
    // Observe & update pro stuff
    [[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(updateProView:)
												 name:kKSLicenseStatusChangeNotification
											   object:nil];
	[self updateProView:nil];
	
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

#pragma mark Presentation

- (CGFloat)contentHeightForViewInInspectorForTabViewItem:(NSTabViewItem *)tabViewItem;
{
    NSString *identifier = [tabViewItem identifier];
    
    if ([identifier isEqualToString:@"site"])
    {
        return 386.0f;
    }
    else if ([identifier isEqualToString:@"appearance"])
    {
        return 501.0f;
    }
    else
    {
        return [super contentHeightForViewInInspectorForTabViewItem:tabViewItem];
    }
}

#pragma mark Language

- (void)refresh;
{
    [super refresh];
    
    
    // Match language popup to selection
    NSString *languageCode = [[self inspectedObjectsController]
                              valueForKeyPath:@"selection.master.language"];
    
    NSInteger theIndex = [oLanguagePopup indexOfItemWithRepresentedObject:languageCode];
    BOOL otherLanguage = (theIndex < 0);
    [oLanguageCodeField setEnabled:otherLanguage];
    if (otherLanguage)
    {
        theIndex = [oLanguagePopup indexOfItemWithTag:-1];
    }
    [oLanguagePopup selectItemAtIndex:theIndex];
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
    
	if (isOther)
    {
        // Give focus to language code field
        NSWindow *window = [[self view] window];
        [window makeKeyWindow];
        [window makeFirstResponder:oLanguageCodeField];
    }
    else
    {
        // Persist choice
        NSString *languageCode = [[sender selectedItem] representedObject];
        [[self inspectedObjectsController] setValue:languageCode
                                             forKeyPath:@"selection.master.language"];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == sLanguageObservationContext)
    {
        [self refresh];
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end
