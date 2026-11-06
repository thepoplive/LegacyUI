#import "LUIRootListController.h"
#import "../Core/CUIConfiguration.h"

@interface LUIRootListController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *sections;
@property (nonatomic, strong) NSDictionary *settings;
@end

@implementation LUIRootListController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"LegacyUI";
    self.view.backgroundColor = [UIColor groupTableViewBackgroundColor];

    _settings = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.legacyui.settings.plist"];
    if (!_settings) {
        _settings = @{
            @"Enabled": @YES,
            @"LockScreenEnabled": @YES,
            @"DockEnabled": @YES,
            @"VolumeHUDEnabled": @YES
        };
    }

    [self setupSections];

    _tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:_tableView];
}

- (void)setupSections {
    _sections = @[
        @{
            @"title": @"General",
            @"items": @[
                @{@"key": @"Enabled", @"title": @"LegacyUI Enabled", @"type": @"switch"}
            ]
        },
        @{
            @"title": @"Dock",
            @"items": @[
                @{@"key": @"DockEnabled", @"title": @"Dock Enabled", @"type": @"switch"},
                @{@"key": @"LiquidGlassEnabled", @"title": @"Liquid Glass Dock", @"type": @"switch"}
            ]
        },
        @{
            @"title": @"Volume HUD",
            @"items": @[
                @{@"key": @"VolumeHUDEnabled", @"title": @"Volume HUD Enabled", @"type": @"switch"},
                @{@"key": @"VolumePillEnabled", @"title": @"Volume Pill", @"type": @"switch"}
            ]
        }
    ];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return _sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSDictionary *sec = _sections[section];
    return [sec[@"items"] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return _sections[section][@"title"];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellId];
    }

    NSDictionary *sec = _sections[indexPath.section];
    NSDictionary *item = sec[@"items"][indexPath.row];

    cell.textLabel.text = item[@"title"];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    if ([item[@"type"] isEqualToString:@"switch"]) {
        UISwitch *sw = [[UISwitch alloc] init];
        NSString *key = item[@"key"];
        sw.on = [_settings[key] boolValue];
        sw.tag = indexPath.section * 100 + indexPath.row;
        [sw addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = sw;
    }

    return cell;
}

- (void)switchChanged:(UISwitch *)sender {
    NSInteger section = sender.tag / 100;
    NSInteger row = sender.tag % 100;

    NSDictionary *sec = _sections[section];
    NSDictionary *item = sec[@"items"][row];
    NSString *key = item[@"key"];

    NSMutableDictionary *newSettings = [_settings mutableCopy];
    newSettings[key] = @(sender.on);
    _settings = [newSettings copy];

    [_settings writeToFile:@"/var/mobile/Library/Preferences/com.legacyui.settings.plist" atomically:YES];
    [[CUIConfiguration sharedInstance] loadSettings];
}

@end