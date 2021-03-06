extends Node

signal dead
signal finished
signal quit

export (PackedScene) var Piece

var upper_row = []
var lower_row = []
var upper_select = []
var lower_select = []

var level_clock = 0.0
var round_clock = 0.0
var level_clock_queue = []

var level = 0
var selecting_upper = true
var dead = false

enum PieceTexture {UP, DOWN, NORMAL}

func _ready():
    fill_row(upper_row)
    fill_row(lower_row)

    upper_select = shuffle_array(fill_select(upper_row, upper_select))
    lower_select = shuffle_array(fill_select(lower_row, lower_select))

    map_line(upper_row, GLOBAL.UPPER_ROW, GLOBAL.ROW_SIZE, UP)
    map_line(lower_row, GLOBAL.LOWER_ROW, GLOBAL.ROW_SIZE, DOWN)
    map_line(upper_select, GLOBAL.UPPER_SELECT, GLOBAL.SELECT_SIZE, NORMAL)
    map_line(lower_select, GLOBAL.LOWER_SELECT, GLOBAL.SELECT_SIZE, NORMAL)

func _process(delta):
    level_clock += delta
    round_clock += delta

func fill_row(row):
    while len(row) < GLOBAL.COLUMNS_ROW:
        randomize()
        var digit = randi() % GLOBAL.PIECE_VARIATIONS
        if not digit in row:
            row.append(digit)

# Creates a select row without repeated elements
func fill_select(row_in, row_out):
    row_out = row_in.duplicate()

    while row_out.size() < GLOBAL.COLUMNS_SELECT:
        randomize()
        var digit = randi() % GLOBAL.PIECE_VARIATIONS
        if not digit in row_out:
            row_out.append(digit)
    return row_out

# Fisher-Yates shuffle
func shuffle_array(arr):
    var shuffled = []
    for i in range(arr.size()):
        randomize()
        var index = randi() % arr.size()
        shuffled.push_front(arr[index])
        arr.remove(index)
    return shuffled

# Map array of random numbers to pieces/text
func map_line(row, target_path, size, texture_type):
    for i in range(row.size()):
        var piece = Piece.instance()
        var id = row[i]
        piece.setup(id, size, texture_type)
        get_node(target_path).add_child(piece)

# Appends the current level timer to a queue
func save_level_timer():
    self.level_clock_queue.append(self.level_clock)
    print(level_clock_queue)
    self.level_clock = 0.0

# Sends the quickest level time to the server
func send_level_clock():
    self.level_clock_queue.sort()
    var score = self.level_clock_queue.front()
    if score != null:
        var body = {"key": GLOBAL.KEY, "game": "gamine", "type": "level", "nickname": get_node(GLOBAL.NICKNAME).nickname, "score": score}
        get_node(GLOBAL.NETWORK).post("/entry", body)

# Send the time that it took to complete an entire round
func send_round_clock():
    var score = self.round_clock
    print(round_clock)
    var body = {"key": GLOBAL.KEY, "game": "gamine", "type": "round", "nickname": get_node(GLOBAL.NICKNAME).nickname, "score": score}
    get_node(GLOBAL.NETWORK).post("/entry", body)

# --- Signals ---

# Show visual effects and delete Game when death occurs
func _on_Data_dead():
    self.dead = true
    self.get_parent().get_node("Sound/ErrorBeep").play()
    self.get_parent().get_node("FlashingTimer").start()
    var TimeLeft = self.get_parent().get_node("Timeleft")
    TimeLeft.stop()
    TimeLeft.wait_time = 0.1
    self.get_parent().get_node("GameOver").start()

# Send data to leaderboard after a complete game
func _on_Data_finished():
    # self.level = GLOBAL.COLUMNS_ROW
    var ResultsMenu = get_node(GLOBAL.RESULTSMENU)
    ResultsMenu.level_result = self.level_clock
    ResultsMenu.round_result = self.round_clock
    get_parent().get_node("ResultsMenu").popup()

# Clean game quit
func _on_Data_quit():
    self.get_parent().queue_free()
    var Menu = get_node(GLOBAL.MENU)
    Menu.visible = true
    Menu.play_pause_menu_music()
