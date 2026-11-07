#import "PrefGenericController.h"

@implementation PrefGenericController

- (id)toolbarImage
{
    return nil;
}

- (id)toolbarLabel
{
    return nil;
}

- (void)primaryAction
{
}

- (void)viewWillBeUninstalled
{
}

- (void)viewWillBeInstalled
{
}

- (id)mainView
{
    [self _loadNibIfNeeded];
    return _mainView;
}

- (void)_loadNibIfNeeded
{
    if (_mainView == nil)
        [NSBundle loadNibNamed:[self _nibName] owner:self];
}

- (id)_nibName
{
    return nil;
}

- (void)dealloc
{
    [_mainView release];
    [super dealloc];
}

@end
