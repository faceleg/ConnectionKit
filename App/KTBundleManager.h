//
//  KTBundleManager.h
//  Sandvox
//
//  Copyright (c) 2004-2005, Karelia Software. All rights reserved.
//
//  THIS SOFTWARE IS PROVIDED BY KARELIA SOFTWARE AND ITS CONTRIBUTORS "AS-IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUR OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
//

#import <Cocoa/Cocoa.h>


@class KTAppPlugin;


@interface KTBundleManager : NSObject
{
	@public	// for debugging abilitities

	NSDictionary	*myPluginsByIdentifier;

	NSArray			*myDataSourceObjects;
}

// Returned Dictionaries are composed of identifier-plugin pairs.
- (NSDictionary *)registeredPlugins;
- (KTAppPlugin *)pluginWithIdentifier:(NSString *)identifier;

- (NSDictionary *)pluginsOfType:(NSString *)aPluginType;
- (NSSet *)pagePlugins;		// Use these 2 methods, not -pluginsOfType since they also include
- (NSSet *)pageletPlugins;	// suitable element plugins
- (NSArray *)dataSourceObjects;

- (NSArray *)managedObjectModels;

- (NSString *)pluginReportShowingAll:(BOOL)aShowAll;	// if false, just shows third-party ones


- (void)addPlugins:(NSSet *)plugins
		    toMenu:(NSMenu *)aMenu
		    target:(id)aTarget
		    action:(SEL)anAction
	     pullsDown:(BOOL)isPullDown
	     showIcons:(BOOL)showIcons;

- (void)addPresetPluginsOfType:(NSString *)aPluginType
						toMenu:(NSMenu *)aMenu
						target:(id)aTarget
						action:(SEL)anAction
					 pullsDown:(BOOL)isPullDown
					 showIcons:(BOOL)showIcons;

- (BOOL)loadClassNamed:(NSString *)aClassName pluginType:(NSString *)aPluginType;
- (NSArray *)loadAllPluginClassesOfType:(NSString *)aPluginType instantiate:(BOOL)inInstantiate;


/*! returns array of setOfAllDragSourceAcceptedDragTypesForPagelets:(BOOL)isPagelet */
- (NSArray *)allDragSourceAcceptedDragTypesForPagelets:(BOOL)isPagelet;

/*! returns unionSet of acceptedDragTypes from all known KTDataSources */
- (NSSet *)setOfAllDragSourceAcceptedDragTypesForPagelets:(BOOL)isPagelet;


@end
