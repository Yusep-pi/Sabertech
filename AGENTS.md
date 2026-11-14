# Guía de Automatización y Tiempo Real para Godot con IA

Este proyecto cuenta con soporte para inspección y control en tiempo real mediante **Godot AI Bridge** y los servidores MCP.

## 1. Plugin `godot_ai_bridge`

Ubicado en [res://addons/godot_ai_bridge](file:///C:/Users/luis/Downloads/Sabertech-main/addons/godot_ai_bridge):
- **EditorPlugin activo**: Gestiona un servidor WebSocket local en el puerto `6550`.
- **Autoload de Runtime**: `GodotAIBridgeRuntime` (`res://addons/godot_ai_bridge/runtime_bridge.gd`) permite automatización de runtime durante la ejecución del juego (entradas de teclado, mouse, captura de pantalla, espera de frames).
- **Captura de logs y errores**: Registro en archivo activado en `project.godot` (`debug/file_logging/enable_logging=true`) para capturar salidas y excepciones en vivo.

### Métodos JSON-RPC del Bridge
- `scene_tree.get`: Inspecciona la jerarquía de nodos en tiempo real en la escena abierta.
- `scene_tree.add_node`, `scene_tree.modify_node`, `scene_tree.remove_node`: Modifica nodos en caliente con soporte Undo/Redo.
- `editor.open_scene`, `editor.save_scene`, `editor.run_scene`, `editor.stop_scene`: Control del editor y ejecución de escenas.
- `runtime.status`, `runtime.press_action`, `runtime.click`, `runtime.type_text`, `runtime.capture_screenshot`: Pruebas interactivas en vivo.
- `info.errors`, `info.output`, `info.log_file`: Detección en tiempo real de errores y advertencias de GDScript o del motor.

## 2. Skills Instaladas

Las siguientes skills están disponibles en [.agent/skills](file:///C:/Users/luis/Downloads/Sabertech-main/.agent/skills):
- `godot-interactive`: Flujo completo de inspección, edición en caliente, pruebas y verificación.
- `godot-live-edit`: Manipulación ágil del árbol del editor en tiempo real.
- `godot-code-gen`: Convenciones y generación de GDScript en Godot 4.x.
- `godot-scene-design`: Estructura óptima de nodos y archivos `.tscn`.
- `godot-shader`: Creación y ajuste de shaders 2D/3D.
