//
//  SVCommentsWindowController.h
//  Sandvox
//
//  Created by Terrence Talbot on 11/1/10.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

// Sandvox 2 supports three comment providers: Disqus, Intense Debate, and Facebook Comments
//  support for Haloscan/JS-Kit/Echo has been dropped

// Disqus is far and away the cleanest implementation from a Sandvox user's standpoint
// Intense Debate is nice and has a wealth of features, but installation is somewhat tedious and confusion-prone
// Echo charges minimally $10/month -- they'll make more from Sandvox than Karelia will...

// Disqus <http://disqus.com>
//  installation instructions are at <http://thedisquschecker.disqus.com/admin/sandvox/>
//  with Disqus, all information about the site is configured on disqus.com and tracked by the "shortname" of the site
//  all the user needs to do to connect comments is to enter the (previously registered) site shortname and publish
//
//  one additional possibility is for the UI to show a "cross domain receiver URL" which is basically a URL
//  guaranteed to 404. this allows disqus to play some tricks without reloading the page

// Intense Debate <http://intensedebate.com/>
//  Sandvox is considered an "other platform" in the installation instructions
//  Neil Boyd's S1 instructions: <http://support.intensedebate.com/generic-install/sandvox/>
//  the user needs to log in to ID before instructions can be viewed
//  installation essentially requires use of a unique account id that is embedded in a script in each page
//  e.g., var idcomments_acct = '534f11196811abd2d2d9418c16fe2cd7';
//  once logged in, you can get your site account id via <http://intensedebate.com/sitekey/>
//  the tricky part is that we need the site account id, not the site key, to make the generic install work

// Facebook Comments <http://developers.facebook.com/docs/reference/plugins/comments/>
//  Facebook Comments are intriguing in that they automatically include a like button and can cross-post
//  to the poster's Facebook page. The only trick is that the Sandvox User must obtain an "App ID" for
//  their site and registration for this happens through the Facebook Developer's page and may be a tad
//  intimidating for our users. We'll need careful documentation walking them through this: it's really
//  not bad if you have some help.

// JS-Kit is now called Echo Live <http://aboutecho.com/>
//  JS-Kit requires registration of the site URL on their website
//  JS-Kit does not appear to support more than one comment system per top-level URL path
//  so, web.me.com/mike is supported but web.me.com/mike/site1 and web.me.com/mike/site2 are not supported
//  installation instructions: <http://wiki.aboutecho.com/w/page/19987901/Echo%20-%20Install%20-%20A%20custom%20website>
//
//  All that needs to be done to activate it is to include the proper JavaScript on the page
//  <div class="js-kit-comments" permalink=""></div><script src="http://cdn.js-kit.com/scripts/comments.js"></script>
//
//  we also used to ping a URL at publish time to associate an admin email address with the site URL
//  <http://js-kit.com/api/isv/site-bind?email=ttalbot@karelia.com&site=http://example.com/site/&confirmviaemail=NO>
//  this appears to no longer be supported, we have yet to hear back from Echo
//
//  customers are not impressed with the pricing changes at Echo <http://support.js-kit.com/jskit/topics/why_the_big_price_change>

// Haloscan is officially dead. All Haloscan accounts were converted to Echo accounts last year.
//  <http://wiki.aboutecho.com/w/page/19987926/HaloScan-Upgrade-FAQ?SearchFor=haloscan+upgrade&sp=1>


// all that really happens in this window controller is that certain UI properties are bound to the master while the UI is displayed

#import <Cocoa/Cocoa.h>
@class KTMaster;

@interface SVCommentsWindowController : NSWindowController 
{
    NSObjectController *_objectController;
    NSTextView *_disqusOverview;
    NSTextView *_intenseDebateOverview;
    NSTextView *_facebookCommentsOverview;
}

@property (assign) IBOutlet NSObjectController *objectController;
@property (assign) IBOutlet NSTextView *disqusOverview;
@property (assign) IBOutlet NSTextView *intenseDebateOverview;
@property (assign) IBOutlet NSTextView *facebookCommentsOverview;

- (void)configureComments:(NSWindowController *)sender;
- (void)setMaster:(KTMaster *)master;
- (IBAction)closeSheet:(id)sender;
- (IBAction)windowHelp:(id)sender;

- (IBAction)visitDisqus:(id)sender;
- (IBAction)visitFacebook:(id)sender;
- (IBAction)visitIntenseDebate:(id)sender;

@end
