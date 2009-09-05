/* Copyright © 2007-2009, The Sequential Project
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of the the Sequential Project nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE SEQUENTIAL PROJECT ''AS IS'' AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE SEQUENTIAL PROJECT BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. */
#import "PGPrefController.h"

// Controllers
#import "PGDocumentController.h"

// Categories
#import "NSColorAdditions.h"
#import "NSObjectAdditions.h"
#import "NSScreenAdditions.h"
#import "NSUserDefaultsAdditions.h"

NSString *const PGPrefControllerBackgroundPatternColorDidChangeNotification = @"PGPrefControllerBackgroundPatternColorDidChange";
NSString *const PGPrefControllerDisplayScreenDidChangeNotification          = @"PGPrefControllerDisplayScreenDidChange";

static NSString *const PGDisplayScreenIndexKey = @"PGDisplayScreenIndex";

static NSString *const PGGeneralPaneIdentifier = @"PGGeneralPane";
static NSString *const PGNavigationPaneIdentifier = @"PGNavigationPaneIdentifier";
static NSString *const PGUpdatePaneIdentifier = @"PGUpdatePane";

static PGPrefController *PGSharedPrefController = nil;

@interface PGPrefController(Private)

- (NSString *)_titleForPane:(NSString *)identifier;
- (void)_setCurrentPane:(NSString *)identifier;
- (void)_updateSecondaryMouseActionLabel;

@end

@implementation PGPrefController

#pragma mark +PGPrefController

+ (id)sharedPrefController
{
	return PGSharedPrefController ? PGSharedPrefController : [[[self alloc] init] autorelease];
}

#pragma mark -PGPrefController

- (IBAction)changeDisplayScreen:(id)sender
{
	[self setDisplayScreen:[sender representedObject]];
}
- (IBAction)showPrefsHelp:(id)sender
{
	[[NSHelpManager sharedHelpManager] openHelpAnchor:@"preferences" inBook:@"Sequential Help"];
}
- (IBAction)changePane:(NSToolbarItem *)sender
{
	[self _setCurrentPane:[sender itemIdentifier]];
}

#pragma mark -

- (NSColor *)backgroundPatternColor
{
	NSColor *const color = [[NSUserDefaults standardUserDefaults] AE_decodedObjectForKey:@"PGBackgroundColor"];
	return [[[NSUserDefaults standardUserDefaults] objectForKey:@"PGBackgroundPattern"] unsignedIntegerValue] == PGCheckerboardPattern ? [color AE_checkerboardPatternColor] : color;
}
- (NSScreen *)displayScreen
{
	return [[_displayScreen retain] autorelease];
}
- (void)setDisplayScreen:(NSScreen *)aScreen
{
	[_displayScreen autorelease];
	_displayScreen = [aScreen retain];
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithUnsignedInteger:[[NSScreen screens] indexOfObjectIdenticalTo:aScreen]] forKey:PGDisplayScreenIndexKey];
	[self AE_postNotificationName:PGPrefControllerDisplayScreenDidChangeNotification];
}

#pragma mark -PGPrefController(Private)

- (NSString *)_titleForPane:(NSString *)identifier
{
	if([PGGeneralPaneIdentifier isEqualToString:identifier]) {
		return NSLocalizedString(@"General", @"Title of general pref pane.");
	} else if([PGNavigationPaneIdentifier isEqualToString:identifier]) {
		return NSLocalizedString(@"Navigation", @"Title of navigation pref pane.");
	} else if([PGUpdatePaneIdentifier isEqualToString:identifier]) {
		return NSLocalizedString(@"Update", @"Title of update pref pane.");
	}
	return @"";
}
- (void)_setCurrentPane:(NSString *)identifier
{
	NSView *view = nil;
	if([PGGeneralPaneIdentifier isEqualToString:identifier]) view = generalView;
	else if([PGNavigationPaneIdentifier isEqualToString:identifier]) view = navigationView;
	else if([PGUpdatePaneIdentifier isEqualToString:identifier]) view = updateView;
	NSAssert(view, @"Invalid identifier.");
	NSWindow *const w = [self window];
	[w setTitle:NSLocalizedString(@"Preferences", nil)];
	[[w toolbar] setSelectedItemIdentifier:identifier];
	if([w contentView] != view) {
		[w setContentView:[[[NSView alloc] initWithFrame:NSZeroRect] autorelease]];
		NSRect r = [w contentRectForFrameRect:[w frame]];
		CGFloat const h = NSHeight([view frame]);
		r.origin.y += NSHeight(r) - h;
		r.size.height = h;
		[w setFrame:[w frameRectForContentRect:r] display:YES animate:YES];
		[w setContentView:view];
	}
}
- (void)_updateSecondaryMouseActionLabel
{
	NSString *label = @"";
	switch([[[NSUserDefaults standardUserDefaults] objectForKey:PGMouseClickActionKey] integerValue]) {
		case PGNextPreviousAction: label = @"Secondary click goes to the previous page."; break;
		case PGLeftRightAction: label = @"Secondary click goes right."; break;
		case PGRightLeftAction: label = @"Secondary click goes left."; break;
	}
	[secondaryMouseActionLabel setStringValue:NSLocalizedString(label, @"Informative string for secondary mouse button action.")];
}

#pragma mark -NSWindowController

- (void)windowDidLoad
{
	[super windowDidLoad];
	NSWindow *const w = [self window];

	NSToolbar *const toolbar = [[[NSToolbar alloc] initWithIdentifier:@"PGPrefControllerToolbar"] autorelease];
	[toolbar setDelegate:self];
	[w setToolbar:toolbar];

	[self _setCurrentPane:PGGeneralPaneIdentifier];
	[w center];
	[self _updateSecondaryMouseActionLabel];
	[self applicationDidChangeScreenParameters:nil];
}

#pragma mark -NSObject

- (id)init
{
	if((self = [super initWithWindowNibName:@"PGPreferences"])) {
		if(PGSharedPrefController) {
			[self release];
			return [PGSharedPrefController retain];
		} else PGSharedPrefController = [self retain];

		NSArray *const screens = [NSScreen screens];
		NSUInteger const screenIndex = [[[NSUserDefaults standardUserDefaults] objectForKey:PGDisplayScreenIndexKey] unsignedIntegerValue];
		[self setDisplayScreen:screenIndex >= [screens count] ? [NSScreen AE_mainScreen] : [screens objectAtIndex:screenIndex]];

		[NSApp AE_addObserver:self selector:@selector(applicationDidChangeScreenParameters:) name:NSApplicationDidChangeScreenParametersNotification];
		[[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:PGBackgroundColorKey options:kNilOptions context:self];
		[[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:PGBackgroundPatternKey options:kNilOptions context:self];
		[[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:PGMouseClickActionKey options:kNilOptions context:self];
	}
	return self;
}
- (void)dealloc
{
	[self AE_removeObserver];
	[[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:PGBackgroundColorKey];
	[[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:PGBackgroundPatternKey];
	[[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:PGMouseClickActionKey];
	[super dealloc];
}

#pragma mark -NSObject(NSKeyValueObserving)

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if(context != self) return [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	if([keyPath isEqualToString:PGMouseClickActionKey]) [self _updateSecondaryMouseActionLabel];
	else [self AE_postNotificationName:PGPrefControllerBackgroundPatternColorDidChangeNotification];
}

#pragma mark -<NSApplicationDelegate>

- (void)applicationDidChangeScreenParameters:(NSNotification *)aNotif
{
	NSArray *const screens = [NSScreen screens];
	[screensPopUp removeAllItems];
	BOOL const hasScreens = [screens count] != 0;
	[screensPopUp setEnabled:hasScreens];
	if(!hasScreens) return [self setDisplayScreen:nil];

	NSScreen *const currentScreen = [self displayScreen];
	NSUInteger i = [screens indexOfObjectIdenticalTo:currentScreen];
	if(NSNotFound == i) {
		i = [screens indexOfObject:currentScreen];
		[self setDisplayScreen:[screens objectAtIndex:NSNotFound == i ? 0 : i]];
	} else [self setDisplayScreen:[self displayScreen]]; // Post PGPrefControllerDisplayScreenDidChangeNotification.

	NSMenu *const screensMenu = [screensPopUp menu];
	for(i = 0; i < [screens count]; i++) {
		NSScreen *const screen = [screens objectAtIndex:i];
		NSMenuItem *const item = [[[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"%@ (%lux%lu)", (i ? [NSString stringWithFormat:NSLocalizedString(@"Screen %lu", @"Non-primary screens. %lu is replaced with the screen number."), (unsigned long)i + 1] : NSLocalizedString(@"Main Screen", @"The primary screen.")), (unsigned long)NSWidth([screen frame]), (unsigned long)NSHeight([screen frame])] action:@selector(changeDisplayScreen:) keyEquivalent:@""] autorelease];
		[item setRepresentedObject:screen];
		[item setTarget:self];
		[screensMenu addItem:item];
		if([self displayScreen] == screen) [screensPopUp selectItem:item];
	}
}

#pragma mark -<NSToolbarDelegate>

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)ident willBeInsertedIntoToolbar:(BOOL)flag
{
	NSToolbarItem *const item = [[[NSToolbarItem alloc] initWithItemIdentifier:ident] autorelease];
	[item setTarget:self];
	[item setAction:@selector(changePane:)];
	[item setLabel:[self _titleForPane:ident]];
	if([PGGeneralPaneIdentifier isEqualToString:ident]) {
		[item setImage:[NSImage imageNamed:@"Pref-General"]];
	} else if([PGNavigationPaneIdentifier isEqualToString:ident]) {
		[item setImage:[NSImage imageNamed:@"Pref-Navigation"]];
	} else if([PGUpdatePaneIdentifier isEqualToString:ident]) {
		[item setImage:[NSImage imageNamed:@"Pref-Update"]];
	}
	return item;
}
- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar
{
	return [NSArray arrayWithObjects:PGGeneralPaneIdentifier, PGNavigationPaneIdentifier, NSToolbarFlexibleSpaceItemIdentifier, PGUpdatePaneIdentifier, nil];
}
- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar
{
	return [self toolbarDefaultItemIdentifiers:toolbar];
}
- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar
{
	return [self toolbarDefaultItemIdentifiers:toolbar];
}

@end
