
extends Node3D

# ==========================================
# КОМНАТА 404
# Первая игровая версия
# Godot 4.7.2
# ==========================================

const SPEED := 3.5
const MOUSE_SENS := 0.003
const MAX_LOOK := 1.35

var camera: Camera3D
var player: CharacterBody3D
var ray: RayCast3D

var yaw := 0.0
var pitch := 0.0
var gravity := 9.8

var inventory: Array[String] = []
var flags := {
    "note": false,
    "trusted": false,
    "truth": false,
    "secret": false
}

var current_interaction: Dictionary = {}
var game_finished := false
var mobile_look := false
var look_touch := -1
var move_vector := Vector2.ZERO

var ui: CanvasLayer
var message_label: Label
var hint_label: Label
var inventory_label: Label
var dialogue_panel: Panel
var dialogue_label: Label
var touch_controls: Control
var joystick_label: Label

var objects: Dictionary = {}

# ==========================================
# ЗАПУСК
# ==========================================

func _ready():
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    create_world()
    create_player()
    create_interface()
    create_story_objects()

    show_message("КОМНАТА 404\nТы проснулся в неизвестном месте...", 5.0)
    update_inventory()


# ==========================================
# МИР
# ==========================================

func create_world():
    var environment := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.015, 0.02, 0.018)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.35, 0.38, 0.32)
    env.ambient_light_energy = 0.45
    environment.environment = env
    add_child(environment)

    var light := DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-45, -25, 0)
    light.light_energy = 0.25
    add_child(light)

    make_box("Floor", Vector3(8, 0.2, 8),
        Vector3(0, -0.1, 0), Color(0.16, 0.16, 0.15))

    make_box("Ceiling", Vector3(8, 0.2, 8),
        Vector3(0, 3.1, 0), Color(0.08, 0.085, 0.08))

    make_box("BackWall", Vector3(8, 3, 0.2),
        Vector3(0, 1.4, -4), Color(0.28, 0.27, 0.23))

    make_box("LeftWall", Vector3(0.2, 3, 8),
        Vector3(-4, 1.4, 0), Color(0.23, 0.23, 0.20))

    make_box("RightWall", Vector3(0.2, 3, 8),
        Vector3(4, 1.4, 0), Color(0.23, 0.23, 0.20))

    # Передняя стена с дверным проёмом
    make_box("FrontLeft", Vector3(3.4, 3, 0.2),
        Vector3(-2.3, 1.4, 4), Color(0.28, 0.27, 0.23))

    make_box("FrontRight", Vector3(3.4, 3, 0.2),
        Vector3(2.3, 1.4, 4), Color(0.28, 0.27, 0.23))

    make_box("FrontTop", Vector3(1.2, 0.8, 0.2),
        Vector3(0, 2.5, 4), Color(0.28, 0.27, 0.23))

    make_box("Door", Vector3(1.1, 2.2, 0.12),
        Vector3(0, 1.1, 3.88), Color(0.10, 0.065, 0.045))

    make_box("Desk", Vector3(1.6, 0.15, 0.8),
        Vector3(-1.7, 0.9, -1.5), Color(0.22, 0.13, 0.08))

    make_box("DeskLeg1", Vector3(0.1, 0.9, 0.1),
        Vector3(-2.35, 0.45, -1.8), Color(0.12, 0.08, 0.05))

    make_box("DeskLeg2", Vector3(0.1, 0.9, 0.1),
        Vector3(-1.05, 0.45, -1.8), Color(0.12, 0.08, 0.05))

    make_box("DeskLeg3", Vector3(0.1, 0.9, 0.1),
        Vector3(-2.35, 0.45, -1.2), Color(0.12, 0.08, 0.05))

    make_box("DeskLeg4", Vector3(0.1, 0.9, 0.1),
        Vector3(-1.05, 0.45, -1.2), Color(0.12, 0.08, 0.05))


func make_box(object_name: String, size: Vector3,
        pos: Vector3, color: Color):
    var body := StaticBody3D.new()
    body.name = object_name
    body.position = pos

    var mesh_instance := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    mesh_instance.mesh = mesh

    var material := StandardMaterial3D.new()
    material.albedo_color = color
    mesh_instance.material_override = material
    body.add_child(mesh_instance)

    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    collision.shape = shape
    body.add_child(collision)

    add_child(body)


# ==========================================
# ИГРОК И КАМЕРА
# ==========================================

func create_player():
    player = CharacterBody3D.new()
    player.name = "Player"
    player.position = Vector3(0, 0.1, 1.5)
    add_child(player)

    var collision := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.3
    capsule.height = 1.8
    collision.shape = capsule
    collision.position.y = 0.9
    player.add_child(collision)

    camera = Camera3D.new()
    camera.position.y = 1.6
    camera.current = true
    player.add_child(camera)

    ray = RayCast3D.new()
    ray.target_position = Vector3(0, 0, -3)
    ray.enabled = true
    ray.collide_with_areas = true
    ray.collide_with_bodies = true
    camera.add_child(ray)


func _physics_process(delta):
    if game_finished:
        return

    var direction := Vector3.ZERO

    if player:
        var input_dir := move_vector

        if Input.is_key_pressed(KEY_W):
            input_dir.y -= 1
        if Input.is_key_pressed(KEY_S):
            input_dir.y += 1
        if Input.is_key_pressed(KEY_A):
            input_dir.x -= 1
        if Input.is_key_pressed(KEY_D):
            input_dir.x += 1

        input_dir = input_dir.limit_length(1.0)

        direction = player.global_transform.basis * Vector3(
            input_dir.x, 0, input_dir.y
        )

        player.velocity.x = direction.x * SPEED
        player.velocity.z = direction.z * SPEED

        if not player.is_on_floor():
            player.velocity.y -= gravity * delta
        else:
            player.velocity.y = 0

        player.move_and_slide()

    check_interaction()


# ==========================================
# ОБЗОР
# ==========================================

func _unhandled_input(event):
    if game_finished:
        return

    if event is InputEventMouseMotion:
        if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
            rotate_camera(event.relative)

    if event is InputEventScreenTouch:
        if event.pressed:
            if event.position.x > get_viewport().size.x * 0.4:
                look_touch = event.index
        elif event.index == look_touch:
            look_touch = -1

    if event is InputEventScreenDrag:
        if event.index == look_touch:
            rotate_camera(event.relative)

    if event is InputEventKey:
        if event.pressed and event.keycode == KEY_ESCAPE:
            Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func rotate_camera(relative: Vector2):
    yaw -= relative.x * MOUSE_SENS
    pitch -= relative.y * MOUSE_SENS
    pitch = clamp(pitch, -MAX_LOOK, MAX_LOOK)

    player.rotation.y = yaw
    camera.rotation.x = pitch


# ==========================================
# СЮЖЕТНЫЕ ОБЪЕКТЫ
# ==========================================

func create_story_objects():
    add_interactive("note", "Записка", Vector3(-1.7, 1.08, -1.5),
        Color(0.85, 0.82, 0.68), "note")

    add_interactive("key", "Старый ключ", Vector3(1.5, 0.25, -1.5),
        Color(0.8, 0.65, 0.2), "key")

    add_interactive("clock", "Часы", Vector3(0, 2.1, -3.85),
        Color(0.4, 0.4, 0.35), "clock")

    add_interactive("door", "Дверь 404", Vector3(0, 1.1, 3.7),
        Color(0.1, 0.08, 0.06), "door")

    add_interactive("phone", "Старый телефон", Vector3(-2.8, 0.5, 0),
        Color(0.12, 0.12, 0.12), "phone")

    add_interactive("code", "Кодовый замок", Vector3(0.8, 1.4, 3.75),
        Color(0.3, 0.3, 0.32), "code")


func add_interactive(id: String, title: String, pos: Vector3,
        color: Color, kind: String):
    var area := Area3D.new()
    area.name = id
    area.position = pos
    area.set_meta("title", title)
    area.set_meta("kind", kind)

    var mesh_instance := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = Vector3(0.35, 0.25, 0.12)
    mesh_instance.mesh = mesh

    var material := StandardMaterial3D.new()
    material.albedo_color = color
    mesh_instance.material_override = material
    area.add_child(mesh_instance)

    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(0.5, 0.4, 0.3)
    collision.shape = shape
    area.add_child(collision)

    add_child(area)
    objects[id] = area


# ==========================================
# ВЗАИМОДЕЙСТВИЕ
# ==========================================

func check_interaction():
    if ray == null:
        return

    ray.force_raycast_update()

    if ray.is_colliding():
        var hit = ray.get_collider()

        if hit is Area3D and hit.has_meta("kind"):
            current_interaction = {
                "id": hit.name,
                "title": hit.get_meta("title"),
                "kind": hit.get_meta("kind")
            }
            hint_label.text = "[ E / ВЗАИМОДЕЙСТВИЕ ] " + str(
                current_interaction.title
            )
            return

    current_interaction = {}
    hint_label.text = "Осмотрите комнату..."


func interact():
    if current_interaction.is_empty():
        return

    var kind: String = current_interaction.kind

    match kind:
        "note":
            flags.note = true
            show_dialogue(
                "Записка",
                "Если ты читаешь это, значит, проснулся в комнате 404.\n\n"
                + "Не открывай дверь, пока часы не покажут 04:04.\n"
                + "И никогда не отвечай голосу из телефона."
            )

        "key":
            if not inventory.has("key"):
                inventory.append("key")
                remove_object("key")
                update_inventory()
                show_message("Ты нашёл старый ключ.", 3.0)
            else:
                show_message("Ключ уже у тебя.", 2.0)

        "clock":
            show_dialogue(
                "Старые часы",
                "Стрелки остановились на 04:04.\n"
                + "На задней крышке выгравировано число: 731."
            )

        "door":
            if inventory.has("key"):
                show_dialogue(
                    "Дверь",
                    "Ключ подходит. За дверью слышен тихий голос."
                )
                flags.secret = true
            else:
                show_message("Дверь заперта. Нужен ключ.", 3.0)

        "phone":
            show_dialogue(
                "Телефон",
                "Из трубки раздаётся голос:\n\n"
                + "— Наконец-то. Я думал, ты никогда не проснёшься.\n\n"
                + "Ответить ему?"
            )
            add_choice_buttons()

        "code":
            if flags.note:
                show_dialogue(
                    "Кодовый замок",
                    "На экране нужно ввести четыре цифры.\n"
                    + "Подсказка: время на часах."
                )
                add_code_buttons()
            else:
                show_message("Нужна подсказка.", 2.0)


func remove_object(id: String):
    if objects.has(id):
        objects[id].queue_free()
        objects.erase(id)


# ==========================================
# РЕШЕНИЯ И КОД
# ==========================================

func add_choice_buttons():
    clear_dialogue_buttons()

    add_dialogue_button("Ответить", func():
        flags.trusted = true
        show_dialogue(
            "Голос",
            "— Хорошо. Тогда слушай внимательно. "
            + "Не верь человеку за дверью."
        )
    )

    add_dialogue_button("Положить трубку", func():
        flags.trusted = false
        show_dialogue(
            "Тишина",
            "Ты положил трубку. Через несколько секунд "
            + "телефон снова начинает звонить."
        )
    )


func add_code_buttons():
    clear_dialogue_buttons()

    add_dialogue_button("0404", func():
        flags.truth = true
        show_dialogue(
            "Замок",
            "Код принят. Где-то в комнате щёлкнул механизм."
        )
        unlock_secret()
    )

    add_dialogue_button("7310", func():
        show_message("Неверный код.", 2.0)
    )


func unlock_secret():
    flags.secret = true
    show_message("Ты услышал, как открылась скрытая дверь.", 4.0)


# ==========================================
# КОНЦОВКИ
# ==========================================

func finish_game(ending: String, description: String):
    game_finished = true
    dialogue_panel.visible = true
    dialogue_label.text = ending + "\n\n" + description
    clear_dialogue_buttons()

    add_dialogue_button("Начать заново", func():
        get_tree().reload_current_scene()
    )


func ending_check():
    if flags.truth and flags.secret and flags.trusted:
        finish_game(
            "КОНЦОВКА 3 — ПРАВДА",
            "Ты узнал, кто создал комнату 404. "
            + "Теперь пространство больше не скрывает от тебя свои тайны."
        )
    elif flags.secret and flags.trusted:
        finish_game(
            "КОНЦОВКА 4 — СМОТРИТЕЛЬ",
            "Ты услышал предложение остаться. "
            + "Теперь ты будешь следить за теми, кто проснётся здесь."
        )
    elif inventory.has("key") and not flags.trusted:
        finish_game(
            "КОНЦОВКА 1 — ВЫХОД",
            "Дверь открылась. Ты выходишь наружу. "
            + "Но почему на твоём телефоне снова 04:04?"
        )
    else:
        finish_game(
            "КОНЦОВКА 2 — ЗАМКНУТЫЙ КРУГ",
            "Ты возвращаешься в исходную комнату. "
            + "На двери снова написано 404."
        )


# ==========================================
# ИНТЕРФЕЙС
# ==========================================

func create_interface():
    ui = CanvasLayer.new()
    add_child(ui)

    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ui.add_child(root)

    message_label = Label.new()
    message_label.position = Vector2(20, 20)
    message_label.add_theme_font_size_override("font_size", 22)
    root.add_child(message_label)

    hint_label = Label.new()
    hint_label.anchor_left = 0.5
    hint_label.anchor_top = 0.82
    hint_label.anchor_right = 0.5
    hint_label.anchor_bottom = 0.82
    hint_label.position = Vector2(-170, 0)
    hint_label.add_theme_font_size_override("font_size", 17)
    root.add_child(hint_label)

    inventory_label = Label.new()
    inventory_label.position = Vector2(20, 65)
    root.add_child(inventory_label)

    dialogue_panel = Panel.new()
    dialogue_panel.anchor_left = 0.1
    dialogue_panel.anchor_top = 0.58
    dialogue_panel.anchor_right = 0.9
    dialogue_panel.anchor_bottom = 0.96
    dialogue_panel.visible = false
    root.add_child(dialogue_panel)

    var box := VBoxContainer.new()
    box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    box.add_theme_constant_override("separation", 8)
    dialogue_panel.add_child(box)

    dialogue_label = Label.new()
    dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    dialogue_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
    dialogue_label.add_theme_font_size_override("font_size", 17)
    box.add_child(dialogue_label)

    var close_button := Button.new()
    close_button.text = "Продолжить"
    close_button.pressed.connect(close_dialogue)
    box.add_child(close_button)

    touch_controls = Control.new()
    touch_controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(touch_controls)

    var interact_button := Button.new()
    interact_button.text = "ВЗАИМОДЕЙСТВИЕ"
    interact_button.anchor_left = 0.72
    interact_button.anchor_top = 0.78
    interact_button.anchor_right = 0.98
    interact_button.anchor_bottom = 0.91
    interact_button.pressed.connect(interact)
    touch_controls.add_child(interact_button)

    var up := make_button("↑", Vector2(85, -115))
    var down := make_button("↓", Vector2(85, -45))
    var left := make_button("←", Vector2(15, -45))
    var right := make_button("→", Vector2(155, -45))

    up.button_down.connect(func(): move_vector.y = -1)
    up.button_up.connect(func(): move_vector.y = 0)
    down.button_down.connect(func(): move_vector.y = 1)
    down.button_up.connect(func(): move_vector.y = 0)
    left.button_down.connect(func(): move_vector.x = -1)
    left.button_up.connect(func(): move_vector.x = 0)
    right.button_down.connect(func(): move_vector.x = 1)
    right.button_up.connect(func(): move_vector.x = 0)


func make_button(text_value: String, offset: Vector2) -> Button:
    var button := Button.new()
    button.text = text_value
    button.position = Vector2(20, get_viewport().size.y - 190) + offset
    button.size = Vector2(60, 60)
    touch_controls.add_child(button)
    return button


func show_message(text_value: String, duration: float):
    message_label.text = text_value


func show_dialogue(title: String, text_value: String):
    dialogue_panel.visible = true
    dialogue_label.text = title + "\n\n" + text_value
    clear_dialogue_buttons()


func close_dialogue():
    dialogue_panel.visible = false
    clear_dialogue_buttons()


func clear_dialogue_buttons():
    # Дополнительные кнопки решений создаются
    # в отдельной версии интерфейса.
    pass


func add_dialogue_button(text_value: String, callback: Callable):
    var button := Button.new()
    button.text = text_value
    button.pressed.connect(callback)

    var box = dialogue_panel.get_child(0)
    box.add_child(button)


func update_inventory():
    inventory_label.text = "ИНВЕНТАРЬ: " + (
        ", ".join(inventory) if not inventory.is_empty() else "пусто"
    )

