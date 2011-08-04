//
//  MapInspector.h
//  MapElement
//
//  Created by Terrence Talbot on 8/3/11.
//  Copyright 2011 Terrence Talbot. All rights reserved.
//

#import <Sandvox.h>


@interface MapInspector : SVInspectorViewController
{
    IBOutlet NSButton *oGoogleMapsButton;
}

- (IBAction)openGoogleMaps:(id)sender;

@end
