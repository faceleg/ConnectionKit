//
//  SVInspectorButton.h
//  Sandvox
//
//  Created by Mike on 16/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

//  Takes the standard button cell, but adjusts the state behaviour to match Pages. i.e. the -nextState is _a_lways NSOnState so that the only way for the user to deselect the button is to click another.


#import <Cocoa/Cocoa.h>


@interface SVInspectorButtonCell : NSButtonCell
{

}

@end
