//
//  KTPluginInstallerController.m
//  Marvel
//
//  Created by Dan Wood on 1/29/08.
//  Copyright 2008 Karelia Software. All rights reserved.
//
//


#import "KTPluginInstallerController.h"

#import "KTAppDelegate.h"
#import "KTImageLoader.h"
#import "KTPluginLoader.h"
#import "NSString+Karelia.h"
#import "NSBundle+Karelia.h"
#import "NSWorkspace+Karelia.h"

@interface KTPluginTableView : NSTableView
@end
@interface KTPluginButtonCell : NSButtonCell
@end

static KTPluginInstallerController *sSharedPluginInstallerController = nil;

@implementation KTPluginInstallerController

#pragma mark -
#pragma mark Loading

+ (KTPluginInstallerController *)sharedController;
{
    if ( nil == sSharedPluginInstallerController ) {
        sSharedPluginInstallerController = [[self alloc] init];
    }
    return sSharedPluginInstallerController;
}

+ (KTPluginInstallerController *)sharedControllerWithoutLoading;
{
	return sSharedPluginInstallerController;
}

- (IBAction)showWindow:(id)sender;
{
	[self setPrompt:NSLocalizedString(@"Check the plugins you wish to install.",@"")];
	[self setPromptColor:[NSColor grayColor]];
	[self setShowOnlyUpdates:NO];
	[oArrayController setFilterPredicate:nil];

	[self prepareForDisplay];
	[super showWindow:sender];
	[[self window] makeKeyAndOrderFront:sender];

	[[NSApp delegate] performSelector:@selector(checkPlaceholderWindow:) 
						   withObject:nil
						   afterDelay:0.0];
	
}

- (IBAction)showWindowForNewVersions:(id)sender;
{
	[self setPrompt:NSLocalizedString(@"Plugins need to be updated.",@"")];
	[self setPromptColor:[NSColor redColor]];
	[self setShowOnlyUpdates:YES];
	[oArrayController setFilterPredicate:[NSPredicate predicateWithFormat:@"new == TRUE"]];	

	[self prepareForDisplay];
	[super showWindow:sender];
	[[self window] makeKeyAndOrderFront:sender];

	[[NSApp delegate] performSelector:@selector(checkPlaceholderWindow:) 
						   withObject:nil
						   afterDelay:0.0];
	
}

- (id)init
{
    self = [super initWithWindowNibName:@"PluginInstaller"];

	[self loadInformation];	
    return self;
}






- (void)dealloc
{
    [self setPlugins:nil];
	[self setErrorString:nil];
    [self setPrompt:nil];
    [self setPromptColor:nil];
    [self setButtonTitle:nil];
    [self setLoaders:nil];
    [super dealloc];
}





#pragma mark -
#pragma mark KVO


- (void)updateNumberOfCheckedItems
{
	NSArray *checkedArray = [[oArrayController arrangedObjects]
							 filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"install == TRUE"]];
	[self setCheckedCount:[checkedArray count]];
	
}

- (void)observeValueForKeyPath:(NSString *)aKeyPath
                      ofObject:(id)anObject
                        change:(NSDictionary *)aChange
                       context:(void *)aContext
{
	if ([aKeyPath isEqualToString:@"showOnlyUpdates"])
	{
		if (myShowOnlyUpdates)
		{
			[oArrayController setFilterPredicate:[NSPredicate predicateWithFormat:@"new == TRUE"]];
		}
		else
		{
			[oArrayController setFilterPredicate:nil];
		}
	}
}

#pragma mark -
#pragma mark Data Manipulation

- (NSArray *)pluginsNeedingUpdate
{
	return [[self plugins] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"new == TRUE"]];
}


// Return a dictionary, or NIL if the item is already loaded and up to date!

- (NSMutableDictionary *)adjustedDictionaryFromDictionary:(NSDictionary *)aDict placeholder:(NSImage *)anImage size:(NSSize)aSize radius:(float)aRadius
{
	// Set up the dictionary, based on the given dictionary from the server ... but we will be adding and removing keys.
	
	NSMutableDictionary *newDict = [NSMutableDictionary dictionaryWithDictionary:aDict];
	
	// Size the given image, and store it both as 'icon' (bound to display) and 'originalIcon' (for making badges)
	
	[anImage setScalesWhenResized:YES];
	[anImage setSize:aSize];
	[newDict setValue:anImage forKey:@"originalIcon"];
	[newDict setValue:anImage forKey:@"icon"];
	[newDict setObject:[NSColor blackColor] forKey:@"textColor"];

	// Convert BundleFile to BundleURL.  We might remove BundleURL later if we disable downloading for any reason.
	NSString *bundleFile = [newDict objectForKey:@"BundleFile"];
	if (bundleFile)
	{
		NSString *urlString = [NSString stringWithFormat:@"http://launch.karelia.com/sandvox.plugins/%@", [bundleFile urlEncodeNoPlus]];
		NSURL *url = [NSURL URLWithString:urlString];
		if (nil == url)
		{
			NSLog(@"Whoa, can't make a URL out of %@", urlString);
			[newDict removeObjectForKey:@"BundleFile"];
		}
		else
		{
			[newDict setObject:url forKey:@"BundleURL"];
		}
	}
	
	// Check if we are running an application that isn't ready for this version.  If it's not ready,
	// set a warning string, and remove 'BundleURL' key to prevent downloading.
	
	NSString *warningString = @"";
	// Check minimum app version.  If not up to snuff, put an explanation text, and disable 'BundleURL" which allows access to the file.
	NSString *minAppVersionString = [newDict objectForKey:@"MinimumAppVersion"];
	NSString *appVersionString = [[NSBundle mainBundle] version];
	float minAppVersion = [minAppVersionString floatVersion];
	float appVersion = [appVersionString floatVersion];
	BOOL needsNewAppVersion = (minAppVersionString && (appVersion < minAppVersion) );
	if (needsNewAppVersion)
	{
		warningString = [NSString stringWithFormat:@"<span style='color:red;'>%@</span>",
									[NSString stringWithFormat:NSLocalizedString(@"Requires Sandvox version %@.", @"warning shown after [English] description of a plugin or design in the plugin installer window"), 
									 minAppVersionString]];
		[newDict removeObjectForKey:@"BundleURL"];
	}
	
	// Check if we already have a version of this plugin.
	
	NSBundle *existingBundle = [NSBundle bundleWithIdentifier:[newDict objectForKey:@"CFBundleIdentifier"]];
	if (existingBundle)
	{
		NSDictionary * info = [existingBundle infoDictionary];
		
		// Check if the server version is newer than what we have.  If so, set a warning string for debugging,
		// and adjust the background color, and mark this a being new.
		
		int existingVersion =  [[info    objectForKey:@"CFBundleVersion"] intValue];
		int availableVersion = [[newDict objectForKey:@"CFBundleVersion"] intValue];
		BOOL isNew = false;
		if (existingVersion > 1 && availableVersion > 1)	// only check if I have a reasonable value
		{
			isNew = (availableVersion > existingVersion);
			if (isNew)
			{
#ifdef DEBUG
				// DEBUG only -- show information about the available vs. current version.
				warningString = [NSString stringWithFormat:@"<span style='color:red; font-size:50%%;'>%d > %d</span>", availableVersion, existingVersion];
#endif
				[newDict setObject:[NSColor redColor] forKey:@"textColor"];
			}
		}
		[newDict setObject:[NSNumber numberWithBool:isNew] forKey:@"new"];
		
		// BAIL HERE IF THE PLUGIN WE ALREADY HAVE IS NOT NEW.  WE DON'T WANT TO SHOW EXISTING, UP-TO-DATE ITEMS.
		if (!isNew)
		{
			NSLog(@"%@ is Not New -- %d <= %d", [newDict objectForKey:@"CFBundleIdentifier"], existingVersion, availableVersion);
			return nil;
		}
		if (needsNewAppVersion)
		{
			NSLog(@"%@ Needs new app version, so skipping", [newDict objectForKey:@"CFBundleIdentifier"]);
			return nil;
		}
		
		// Below HERE to end of this block is a NEW plugin we don't have.
		
		// set 'install' to YES if this is new and showOnlyUpdates so that when we are notified of new versions
		// automatically, they are already checked.
		[newDict setValue:[NSNumber numberWithBool:isNew && [self showOnlyUpdates]] forKey:@"install"];	// initially check if it's new and we want to show only new things

		// Try to load icon from our *existing* bundle so we don't have to load over the network.
		// If we can, remove 'IconFile' key that loads over the network (below)
		NSString *iconName = [info objectForKey:@"KTPluginIconName"];
		NSString *path = nil;
		if (nil != iconName)
		{
			path = [existingBundle pathForImageResource:iconName];
		}
		if (nil == path)
		{
			path = [existingBundle pathForImageResource:@"thumbnail"];	// design usual name
		}
		if (nil != path)
		{
			NSImage *sourceImage = [[[NSImage alloc] initWithContentsOfFile:path] autorelease];
			NSImage *destImage = [KTImageLoader finalizeImage:sourceImage toSize:aSize radius:aRadius];
			[newDict setObject:destImage forKey:@"originalIcon"];
			[newDict setObject:destImage forKey:@"icon"];
			[newDict removeObjectForKey:@"IconFile"];		// don't need to load remotely!
		}
	}
	else		// A plugin we DON'T HAVE
	{
		NSLog(@"Not finding %@", [newDict objectForKey:@"CFBundleIdentifier"]);
		
		// don't allow downloading of a plugin you don't have if there is a URL.
		// This allows us to have low-security "update only" plugins announced, where you have to 
		// go to a website to download the initial version, but once you have it, you can get
		// updates directly.  NOT A HIGH SECURITY THING, PROBABLY NOT GOOD FOR COMMERCIAL STUFF
		if ([newDict objectForKey:@"URL"])
		{
			[newDict removeObjectForKey:@"BundleURL"];		
		}
		[newDict setObject:[NSColor whiteColor] forKey:@"backgroundColor"];
	}
	
	// CONTINUING ON ... WE MAY OR MAY NOT HAVE THE PLUGIN INSTALLED FROM HERE ON DOWN.
	
	// Load icon remotely if it is needed.
	NSString *iconFileName = [newDict objectForKey:@"IconFile"];
	if (iconFileName)
	{
		NSString *urlString = [NSString stringWithFormat:@"http://launch.karelia.com/sandvox.plugins/%@", [iconFileName urlEncodeNoPlus]];
		NSURL *theURL = [NSURL URLWithString:urlString];
		KTImageLoader *imageLoader = [[[KTImageLoader alloc] initWithURL:theURL
																	size:aSize
																  radius:aRadius
															 destination:newDict] autorelease];
		[newDict setObject:imageLoader forKey:@"imageLoader"];
	}
	
	// Set up the Info HTML string and render as rich text.
	// Append any warning, link to description string
	NSString *infoHTML = [newDict objectForKey:@"InfoHTML"];
	if (warningString)
	{
		if (nil == infoHTML)
		{
			infoHTML = warningString;
		}
		else
		{
			infoHTML = [infoHTML stringByAppendingFormat:@" %@",warningString];	// space between info & warning.
		}
	}
	if (infoHTML)
	{
		NSData *infoData = [infoHTML dataUsingEncoding:NSUTF8StringEncoding];
		NSDictionary *docAttr;
		static WebPreferences *sSystemFontWebPrefs = nil;
		if (nil == sSystemFontWebPrefs)
		{
			sSystemFontWebPrefs = [[WebPreferences alloc] init];
			[sSystemFontWebPrefs setStandardFontFamily:@"Lucida Grande"];
			[sSystemFontWebPrefs setDefaultFontSize:13.0];
		}
		NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
								 @"UTF-8", NSTextEncodingNameDocumentOption,
								 sSystemFontWebPrefs, NSWebPreferencesDocumentOption,
								 nil];
		NSAttributedString *infoString = [[[NSAttributedString alloc] initWithHTML:infoData options:options documentAttributes:&docAttr] autorelease];
		[newDict setObject:infoString forKey:@"InfoAttributedString"];
	}

	// Set up title.  Make attributed so we can get word wrapping.
	NSString *title = [newDict objectForKey:@"title"];
	if (title)
	{
		NSAttributedString *nameString = [[[NSAttributedString alloc] initWithString:title
																		  attributes: [NSDictionary dictionaryWithObjectsAndKeys:[NSFont systemFontOfSize:[NSFont systemFontSize]], NSFontAttributeName, nil]] autorelease];
		[newDict setObject:nameString forKey:@"nameAttributedString"];
	}
	
	return newDict;
}

#pragma mark -
#pragma mark Table View Delegate

- (BOOL)tableView:(NSTableView *)aTableView shouldSelectRow:(int)rowIndex
{
	return NO;
}

// Required for use by our custom table
- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(int)row;
{
	if ([[tableColumn identifier] isEqualToString:@"install"])
	{
		NSArray *objects = [oArrayController arrangedObjects];
		if (row >= 0 && row < [objects count])
		{
			id representedObject = [objects objectAtIndex:row];
			int state = [object state];
			[representedObject setValue:[NSNumber numberWithInt:state] forKey:@"install"];
			[self updateNumberOfCheckedItems];	// hackish way to update UI when checked count changes
		}
	}
}

// ad-hoc action
- (void)tableView:(NSTableView *)tableView sendActionForTableColumn:(NSTableColumn *)tableColumn row:(int)row;
{
	if ([[tableColumn identifier] isEqualToString:@"info"])
	{
		NSArray *objects = [oArrayController arrangedObjects];
		if (row >= 0 && row < [objects count])
		{
			id representedObject = [objects objectAtIndex:row];
			NSString *urlString = [representedObject objectForKey:@"URL"];
			if (urlString)
			{
				NSURL *theURL = [NSURL URLWithString:urlString];
				[[NSWorkspace sharedWorkspace] attemptToOpenWebURL:theURL];
			}
		}
	}
}
#pragma mark -
#pragma mark Window Delegate

- (void)windowDidLoad
{
    [super windowDidLoad];
	[[self window] center];

	[self addObserver:self
		   forKeyPath:@"showOnlyUpdates"
			  options:NSKeyValueObservingOptionNew
			  context:nil];
	
	NSEnumerator *theEnum = [[oTable tableColumns] objectEnumerator];
	NSTableColumn *theCol;
	while (nil != (theCol = [theEnum nextObject]) )
	{
		[[theCol dataCell] setWraps:YES];
		[[theCol dataCell] setLineBreakMode:NSLineBreakByTruncatingTail];	//  NSLineBreakByWordWrapping doesn't work!
	}
	
	theCol = [oTable tableColumnWithIdentifier:@"info"];
	KTPluginButtonCell *buttonCell = [[[KTPluginButtonCell alloc] init] autorelease];
	[buttonCell setTitle:@""];
	NSImage *followImage = [NSImage imageNamed:@"follow15"];		// version optmized for 15 pixels
	[followImage setScalesWhenResized:YES];
	[followImage setSize:NSMakeSize(15,15)];
	[buttonCell setImage:followImage];				// I should probably have a "pushed" equivalent of this as the alternate image.
	[buttonCell setImagePosition:NSImageOnly];
	[buttonCell setButtonType:NSMomentaryChangeButton];			// NOT NSMomentaryLightButton or NSMomentaryPushInButton - ugly background change
	[buttonCell setTag:99];	// hack to be able to distinguish the checkbox from our URL button
	[buttonCell setBordered:NO];
	
	[theCol setDataCell:buttonCell];	
}

- (void) loadInformation
{
	NSArray *plugins = [[[NSApp delegate] homeBaseDict] objectForKey:@"Plugins"];
	NSArray *designs = [[[NSApp delegate] homeBaseDict] objectForKey:@"Designs"];
	NSImage *pluginImage = [NSImage imageNamed:@"pageplugin"];
	NSImage *designImage = [NSImage imageNamed:@"designPlaceholder"];
	
	NSMutableArray *list = [NSMutableArray array];
	
	//  install (bool), icon (image), title, InfoHTML,
	NSEnumerator *theEnum = [plugins objectEnumerator];
	NSDictionary *theDict;
	
	myScaleFactor = [[self window] userSpaceScaleFactor];
	
	while ((theDict = [theEnum nextObject]) != nil)
	{
		NSMutableDictionary *adjustedDict = [self adjustedDictionaryFromDictionary:theDict
																	   placeholder:pluginImage
																			  size:NSMakeSize(64.0 * myScaleFactor,64.0 * myScaleFactor)
																			radius:0.0];	// no radius on icons
		if (adjustedDict)
		{
			[list addObject:adjustedDict];
		}
	}
	
	theEnum = [designs objectEnumerator];
	
	while ((theDict = [theEnum nextObject]) != nil)
	{
		NSMutableDictionary *adjustedDict = [self adjustedDictionaryFromDictionary:theDict
																	   placeholder:designImage
																			  size:NSMakeSize(100.0 * myScaleFactor,65.0 * myScaleFactor)
																			radius:myScaleFactor * 6.0];
		if (adjustedDict)
		{
			[list addObject:adjustedDict];
		}
	}
	[self setPlugins:list];
}

- (void) prepareForDisplay
{
	[self setButtonTitle:NSLocalizedString(@"Download & Install", @"button title")];
	[oTable deselectRow:[oTable selectedRow]];
}

#pragma mark -
#pragma mark Downloading


- (IBAction) downloadSelectedPlugins:(id)sender;
{
	if ([[self loaders] count])		// cancel
	{
		[self setButtonTitle:NSLocalizedString(@"Download & Install", @"button title")];
		NSEnumerator *enumerator = [[self loaders] objectEnumerator];
		KTPluginLoader *loader;

		while ((loader = [enumerator nextObject]) != nil)
		{
			[loader cancel];
		}
		[self setLoaders:nil];
	}
	else
	{
		[self setErrorString:[NSMutableString string]];	// clear out error string
		[self setButtonTitle:NSLocalizedString(@"Stop", @"button title to stop downloading")];
		NSEnumerator *theEnum = [myPlugins objectEnumerator];
		NSMutableDictionary *theDict;
		NSMutableArray *loaders = [NSMutableArray array];
		while (nil != (theDict = [theEnum nextObject]) )
		{
			BOOL reallyInstall = [[theDict objectForKey:@"install"] boolValue];
			if ([self showOnlyUpdates] && ![[theDict objectForKey:@"new"] boolValue])
			{
				reallyInstall = NO;	// don't installl if we are showing only updates, and this is NOT a new update
			}
			
			if (reallyInstall)
			{
				KTPluginLoader *loader = [[KTPluginLoader alloc] initWithDictionary:theDict delegate:self];	// this kicks off the load •
				[loaders addObject:loader];
			}
		}
		[self setLoaders:loaders];
	}
}

- (void) loaderFinished:(KTPluginLoader *)aLoader error:(NSError *)anError;
{
	if (anError)
	{
		// add error to list of errors to display at the end
		[myErrorString appendFormat:@"%@: %@ - %@\n",
			[[aLoader dictionary] objectForKey:@"title"],
			[anError localizedDescription],
			[[[[anError userInfo] objectForKey:NSErrorFailingURLStringKey] description] condenseWhiteSpace] ];
		
		static NSImage *sErrorImage = nil;
		if (nil == sErrorImage)
		{
			sErrorImage = [[NSImage alloc] initWithContentsOfFile:@"/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertStopIcon.icns"];
			[sErrorImage setScalesWhenResized:YES];
		}
		[sErrorImage setSize:NSMakeSize(myScaleFactor * 32.0,myScaleFactor * 32.0)];	// set each time in case scale factor changes while running
		
		NSImage *sourceImage = [[aLoader dictionary] objectForKey:@"originalIcon"];
		sourceImage = [[sourceImage copy] autorelease];
		[sourceImage lockFocus];
		[sErrorImage compositeToPoint:NSMakePoint(2.0,2.0) operation:NSCompositeSourceOver];
		[sourceImage unlockFocus];
		[[aLoader dictionary] setObject:sourceImage forKey:@"icon"];
	}
	else	// loaded, uncheck this now.
	{
		[[aLoader dictionary] setObject:[NSNumber numberWithBool:NO] forKey:@"install"];	// whether to mark as checked

		static NSImage *sCheckmark = nil;
		if (nil == sCheckmark)
		{
			sCheckmark = [[NSImage imageNamed:@"checkmark"] retain];
			[sCheckmark setScalesWhenResized:YES];
		}
		[sCheckmark setSize:NSMakeSize(myScaleFactor * 32.0,myScaleFactor * 32.0)];	// set each time in case scale factor changes while running

		NSImage *sourceImage = [[aLoader dictionary] objectForKey:@"originalIcon"];
		sourceImage = [[sourceImage copy] autorelease];
		[sourceImage lockFocus];
		[sCheckmark compositeToPoint:NSMakePoint(2.0,2.0) operation:NSCompositeSourceOver];
		[sourceImage unlockFocus];
		[[aLoader dictionary] setObject:sourceImage forKey:@"icon"];
		[[aLoader dictionary] removeObjectForKey:@"BundleURL"];			// disable download, since we have it
	}
	[[self loaders] removeObject:aLoader];
	if (0 == [[self loaders] count])
	{
		[self setLoaders:nil];	// clear array. This will help with KVO to notice array has changed.
		[self setButtonTitle:NSLocalizedString(@"Download & Install", @"button title")];		// go back to the download buttton title
		if (![@"" isEqualToString:myErrorString])
		{
			NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Error Downloading Plugins", "alert title")
											 defaultButton:NSLocalizedString(@"OK", "OK Button")
										   alternateButton:nil 
											   otherButton:nil 
								 informativeTextWithFormat:NSLocalizedString(@"Sandvox encountered problems downloading some plugins.  Please report this to Karelia Software.\n\n%@",@""), myErrorString];
			
			[alert beginSheetModalForWindow:[self window] 
							  modalDelegate:nil 
							 didEndSelector:nil
								contextInfo:nil];
		}
	}
}

#pragma mark -
#pragma mark Accessors


- (NSArray *)plugins
{
    return myPlugins; 
}

- (void)setPlugins:(NSArray *)aPlugins
{
    [aPlugins retain];
    [myPlugins release];
    myPlugins = aPlugins;
}


- (BOOL)showOnlyUpdates
{
    return myShowOnlyUpdates;
}

- (void)setShowOnlyUpdates:(BOOL)flag
{
    myShowOnlyUpdates = flag;
}


- (NSString *)prompt
{
    return prompt; 
}

- (void)setPrompt:(NSString *)aPrompt
{
    [aPrompt retain];
    [prompt release];
    prompt = aPrompt;
}

- (NSColor *)promptColor
{
    return promptColor; 
}

- (void)setPromptColor:(NSColor *)aPromptColor
{
    [aPromptColor retain];
    [promptColor release];
    promptColor = aPromptColor;
}


- (int)checkedCount
{
    return myCheckedCount;
}
- (void)setCheckedCount:(int)aCheckedCount
{
    myCheckedCount = aCheckedCount;
}


- (NSString *)buttonTitle
{
    return buttonTitle; 
}

- (void)setButtonTitle:(NSString *)aButtonTitle
{
    [aButtonTitle retain];
    [buttonTitle release];
    buttonTitle = aButtonTitle;
}


- (NSMutableArray *)loaders
{
    return myLoaders; 
}

- (void)setLoaders:(NSMutableArray *)aLoaders
{
    [aLoaders retain];
    [myLoaders release];
    myLoaders = aLoaders;
}


- (NSMutableString *)errorString
{
    return myErrorString; 
}

- (void)setErrorString:(NSMutableString *)anErrorString
{
    [anErrorString retain];
    [myErrorString release];
    myErrorString = anErrorString;
}

@end


// From http://www.cocoadev.com/index.pl?CheckboxInTableWithoutSelectingRow


@implementation KTPluginTableView

- (void)		mouseDown:(NSEvent*) event
{
	NSPoint p = [self convertPoint:[event locationInWindow] fromView:nil];
	
	// which column and cell has been hit?
	
	int column = [self columnAtPoint:p];
	int row = [self rowAtPoint:p];
	NSTableColumn* theColumn = [[self tableColumns] objectAtIndex:column];
	id dataCell = [theColumn dataCellForRow:row];
	
	// if the checkbox column, handle click in checkbox without selecting the row
	
	if ([dataCell isKindOfClass:[NSButtonCell class]])
	{
		// no way to get the button type for further testing, so we'll plough on blindly
		
		NSRect	cellFrame = [self frameOfCellAtColumn:column row:row];
		
		// track the button - this keeps control until the mouse goes up. If the mouse was in on release,
		// it will have changed the button's state and returns YES.
		
		if ([dataCell trackMouse:event inRect:cellFrame ofView:self untilMouseUp:YES])
		{
			if (99 == [dataCell tag])	// the URL one
			{
				[[self delegate] tableView:self sendActionForTableColumn:theColumn row:row];
			}
			else
			{
				[[self delegate] tableView:self setObjectValue:dataCell forTableColumn:theColumn row:row];
			}
			// call the delegate to handle the checkbox state change as normal
		}
	}
	else
		[super mouseDown:event];	// for all other columns, work as normal
}



@end


@implementation KTPluginButtonCell

// Don't draw disabled checkbox/button
- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	if ([self isEnabled])
	{
		[super drawInteriorWithFrame:cellFrame inView:controlView];
	}
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView;
{
	if ([self isEnabled])
	{
		[super drawWithFrame:cellFrame inView:controlView];
	}
}

- (BOOL)	trackMouse:(NSEvent *)theEvent inRect:(NSRect)cellFrame ofView:(NSView *)controlView untilMouseUp:(BOOL)untilMouseUp
{
	[self setHighlighted:YES];
	[controlView setNeedsDisplayInRect:cellFrame];
	
	// keep control until mouse up
	
	NSEvent*	evt;
	BOOL		loop = YES;
	BOOL		wasIn, isIn;
	int			mask = NSLeftMouseUpMask | NSLeftMouseDraggedMask;
	
	wasIn = YES;
	
	while( loop )
	{
		evt = [[controlView window] nextEventMatchingMask:mask];
		
		switch([evt type])
		{
			case NSLeftMouseDragged:
			{
				NSPoint p = [controlView convertPoint:[evt locationInWindow] fromView:nil];
				isIn = NSPointInRect( p, cellFrame );
				
				if ( isIn != wasIn )
				{
					[self setHighlighted:isIn];
					[controlView setNeedsDisplayInRect:cellFrame];
					wasIn = isIn;
				}
			}
				break;
				
			case NSLeftMouseUp:
				loop = NO;
				break;
				
			default:
				break;
		}
		
	}
	
	[self setHighlighted:NO];
	
	// if the mouse was in the cell when it was released, flip the checkbox state
	
	if ( wasIn )
		[self setIntValue:![self intValue]];	// for checkbox.  Doesn't really matter for the pushbutton
	
	[controlView setNeedsDisplayInRect:cellFrame];
	
	return wasIn;
}


@end


