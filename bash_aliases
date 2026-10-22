# Workspace ROS 2 do pan-tilt: entra em /ros2_ws e carrega o ambiente
alias ws='cd /ros2_ws && source /opt/ros/humble/setup.bash && if [ -f install/setup.bash ]; then source install/setup.bash; else echo "[ws] install/ ausente: rode colcon build --symlink-install e depois ws"; fi'
