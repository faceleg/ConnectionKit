//
//  MapInspector.m
//  MapElement
//
//  Created by Terrence Talbot on 8/3/11.
//  Copyright 2011 Terrence Talbot. All rights reserved.
//

#import "MapInspector.h"


@implementation MapInspector



- (void)awakeFromNib
{
    // Lots of work to make a nice colorful logo!
	NSString *poweredByString = [oGoogleMapsButton title];
	
	NSDictionary *attr = [NSDictionary dictionaryWithObjectsAndKeys:
                          [NSFont boldSystemFontOfSize:[NSFont smallSystemFontSize]], NSFontAttributeName,
                          nil];
	NSMutableAttributedString *ms = [[[NSMutableAttributedString alloc] initWithString:poweredByString 
                                                                            attributes:attr] autorelease];
	NSRange googleRange = [poweredByString rangeOfString:@"Google" options:NSCaseInsensitiveSearch];
	if (NSNotFound != googleRange.location)
	{
        // G = blue
		[ms addAttributes:
         [NSDictionary dictionaryWithObjectsAndKeys:
          [NSColor blueColor], NSForegroundColorAttributeName, nil]
					range:NSMakeRange(googleRange.location, 1)];
        
        // o = red
		[ms addAttributes:
         [NSDictionary dictionaryWithObjectsAndKeys:
          [NSColor redColor], NSForegroundColorAttributeName, nil]
					range:NSMakeRange(googleRange.location+1, 1)];
        
        // o = yellow
		[ms addAttributes:
         [NSDictionary dictionaryWithObjectsAndKeys:
          [NSColor yellowColor], NSForegroundColorAttributeName, nil]
					range:NSMakeRange(googleRange.location+2, 1)];
        
        // g = blue
		[ms addAttributes:
         [NSDictionary dictionaryWithObjectsAndKeys:
          [NSColor blueColor], NSForegroundColorAttributeName, nil]
					range:NSMakeRange(googleRange.location+3, 1)];
        
        // l = green
		[ms addAttributes:
         [NSDictionary dictionaryWithObjectsAndKeys:
          [NSColor greenColor], NSForegroundColorAttributeName, nil]
					range:NSMakeRange(googleRange.location+4, 1)];
        
        // e = red
		[ms addAttributes:
         [NSDictionary dictionaryWithObjectsAndKeys:
          [NSColor redColor], NSForegroundColorAttributeName, nil]
					range:NSMakeRange(googleRange.location+5, 1)];
	}
    
	[oGoogleMapsButton setAttributedTitle:ms];
}

- (IBAction)openGoogleMaps:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://maps.google.com/"]];
}

@end
