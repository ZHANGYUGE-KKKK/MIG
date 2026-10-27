# Exempt only the asynchronous entry of the three-stage application reset.
set async_pins [get_pins -hier -regexp {.*app_reset_sync_reg\[[012]\]/PRE}]
set_false_path -to $async_pins
