"""Derive a short profiling probe without modifying the frozen long-soak script."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / 'Godot/three_d/tools/soak_active_tables.gd'
DEST = ROOT / 'output/builds/profile-active-tables.gd'


def replace_once(source, old, new):
    if source.count(old) != 1:
        raise RuntimeError('Profiling insertion anchor changed: ' + old)
    return source.replace(old, new, 1)


def main():
    source = SOURCE.read_text()
    source = replace_once(source, 'var duration := 1800', 'var duration := 120')
    source = replace_once(source, '\tvar samples: Array = []', '\tvar samples: Array = []\n\tvar outliers: Array = []')
    source = replace_once(source, '"samples":samples,"pack_path":', '"samples":samples,"outliers":outliers,"profile_scope":"Tool branch CPU duration and latest engine process/physics monitors; monitors may lag the callback. Event correlation is not independent GPU timing or causal proof.","pack_path":')
    source = replace_once(source, '\t\tvar actor := ""', '\t\tvar loop_started := Time.get_ticks_usec()\n\t\tvar phase_before: String = phase\n\t\tvar actor := ""')
    source = replace_once(source, '\t\tawait RenderingServer.frame_post_draw', '\t\tvar tool_cpu_ms := float(Time.get_ticks_usec()-loop_started)/1000.0\n\t\tawait RenderingServer.frame_post_draw')
    source = replace_once(source, '\t\tframes.append(float(now-previous)/1000.0)', '\t\tvar interval_ms := float(now-previous)/1000.0\n\t\tif interval_ms>16.67:\n\t\t\toutliers.append({"elapsed_seconds":float(now-started)/1000000.0,"phase_before":phase_before,"phase_after":phase,"actor_before":actor,"revision_before":revision,"revision_after":world.table_game.revision if world.table_game!=null else -1,"callback_ms":interval_ms,"tool_cpu_ms":tool_cpu_ms,"engine_process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000.0,"engine_physics_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0})\n\t\tframes.append(interval_ms)')
    DEST.parent.mkdir(parents=True, exist_ok=True)
    DEST.write_text(source)
    print(DEST)


if __name__ == '__main__':
    main()
