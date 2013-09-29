//
//  SlideMenuController.m
//  SlideMenu
//
//  Created by shaohua on 9/29/13.
//
//

#import "SlideMenuController.h"
#import "UIViewAdditions.h"

#define kMenuPercentage 0.85
#define kSlideDuration .1

@interface SlideMenuController () <UITableViewDataSource, UITableViewDelegate> {
    NSMutableArray *_viewControllers;

    UITableView *_tableView; // menu
    UIView *_contentView; // content

    NSUInteger _selectedSection;
    NSUInteger _selectedRow;

    CGRect _savedFrame;
    CGFloat _savedLeft;
    UIView *_maskView;

    dispatch_once_t _onceToken; // select first tab upon first launch
}

@end


@implementation SlideMenuController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor colorWithRed:.9686 green:.9686 blue:.9686 alpha:1];

    CGFloat topHeight = [UIApplication sharedApplication].statusBarFrame.size.height;

    _tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, topHeight, self.view.width * kMenuPercentage, self.view.height - topHeight) style:UITableViewStyleGrouped];
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.backgroundColor = [UIColor colorWithRed:.9647 green:.9608 blue:.9804 alpha:1];
    _tableView.tableFooterView = [[UIView alloc] init];
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
    _tableView.showsVerticalScrollIndicator = NO;
    _tableView.tableFooterView = [[UIView alloc] init];

    [self.view addSubview:_tableView];

    _contentView = [[UIView alloc] initWithFrame:self.view.bounds];
    _contentView.layer.shadowOffset = CGSizeMake(-2, 0);
    _contentView.layer.shadowOpacity = .5;
    _contentView.layer.shadowRadius = 2;
    _contentView.layer.shadowColor = [UIColor colorWithWhite:.8 alpha:1].CGColor;
    _contentView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    [_contentView addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(onContentPanned:)]];
    [self.view addSubview:_contentView];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    dispatch_once(&_onceToken, ^{
        [self showViewControllerWithSection:0 Row:0];
    });
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    _savedFrame = self.view.bounds;
}

- (void)showViewControllerWithSection:(NSUInteger)section Row:(NSUInteger)row {
    if (section < _viewControllers.count && row < [_viewControllers[section] count]) {
        if (!(_selectedSection >= _viewControllers.count || _selectedRow >= [_viewControllers[section] count])) {
            UIViewController *viewController = _viewControllers[_selectedSection][_selectedRow];
            [viewController removeFromParentViewController];
            [viewController.view removeFromSuperview];
        }
        _selectedSection = section;
        _selectedRow = row;
        UIViewController *viewController = _viewControllers[_selectedSection][_selectedRow];
        viewController.view.frame = _contentView.bounds;
        [_contentView addSubview:viewController.view];
        [self addChildViewController:viewController];
    }
    [_tableView reloadData];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    _savedFrame = self.view.bounds;
}

- (void)setViewControllers:(NSArray *)viewControllers {
    _viewControllers = [NSMutableArray array];
    for (int i = 0; i < viewControllers.count; i++) {
        NSMutableArray *array = [NSMutableArray array];
        for (int j = 0; j < [viewControllers[i] count]; j++) {
            UIViewController *viewController = (UIViewController *)viewControllers[i][j];
            if ([viewControllers[i][j] isKindOfClass:[UINavigationController class]]) { // already wrapped
                [_viewControllers addObject:viewController];
                continue;
            }
            UIButton *button = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 34, 24)];
            [button setImage:[UIImage imageNamed:@"Menu"] forState:UIControlStateNormal];
            viewController.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:button];
            [button addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onMenuTapped)]];
            [array addObject:[[UINavigationController alloc] initWithRootViewController:viewController]];
        }
        [_viewControllers addObject:array];
    }
}

- (UIViewController *)selectedViewController {
    if (_selectedSection < _viewControllers.count && _selectedRow < [_viewControllers[_selectedSection] count]) {
        return _viewControllers[_selectedSection][_selectedRow];
    }
    return nil;
}

#pragma mark - Private
- (void)onMenuTapped {
    CGRect shifted = CGRectOffset(_savedFrame, self.view.width * kMenuPercentage, 0);
    [UIView animateWithDuration:kSlideDuration animations:^{
        _contentView.frame = shifted;
    }];
    [_maskView removeFromSuperview]; // avoid race condition
    _maskView = [[UIView alloc] initWithFrame:_savedFrame];
    [_maskView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTransitionTapped:)]];
    [_contentView addSubview:_maskView];
}

- (void)restore {
    [UIView animateWithDuration:kSlideDuration animations:^{
        _contentView.frame = _savedFrame;
    }];
    [_maskView removeFromSuperview];
}

- (void)onTransitionTapped:(UITapGestureRecognizer *)gesture {
    [self restore];
}

- (void)onContentPanned:(UIPanGestureRecognizer *)pan {
    if (pan.state == UIGestureRecognizerStateBegan) {
        _savedLeft = _contentView.left;
    } else if (pan.state == UIGestureRecognizerStateChanged) {
        CGPoint t = [pan translationInView:self.view];
        _contentView.left = _savedLeft + t.x;
        if (_contentView.left < 0) {
            _contentView.left = 0;
        }
        if (_contentView.left > self.view.width * kMenuPercentage) {
            _contentView.left = self.view.width * kMenuPercentage;
        }
    } else if (pan.state == UIGestureRecognizerStateEnded) {
        CGPoint v = [pan velocityInView:self.view];
        if (v.x > self.view.width) {
            [self onMenuTapped];
        } else if (v.x < -self.view.width) {
            [self restore];
        } else {
            if (_contentView.left > self.view.width * .55) {
                [self onMenuTapped];
            } else {
                [self restore];
            }
        }
    }
}

#pragma mark - UITableViewDataSource / UITableViewDelegate
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 5;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return 20;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return _viewControllers.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_viewControllers[section] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UIViewController *viewController = _viewControllers[indexPath.section][indexPath.row];
    static NSString *cellId = @"SLMenuCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellId];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    cell.imageView.image = viewController.tabBarItem.image;
    cell.textLabel.text = viewController.title;

    BOOL selected = _selectedSection == indexPath.section && _selectedRow == indexPath.row;

    cell.textLabel.textColor = selected ? [UIColor colorWithWhite:0.3 alpha:1] : [UIColor colorWithWhite:.5 alpha:1];
    cell.backgroundColor = selected ? [UIColor colorWithWhite:.92 alpha:1] : [UIColor whiteColor];

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    [self showViewControllerWithSection:indexPath.section Row:indexPath.row];
    [self restore];
}

@end
