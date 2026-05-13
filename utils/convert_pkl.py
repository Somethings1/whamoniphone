import json
import pickle
import numpy as np
import os
import logging

# ==============================================================================
# LOGGING CONFIGURATION
# Establishes a standardized logging protocol for runtime monitoring and
# debugging, utilizing timestamped and severity-leveled outputs.
# ==============================================================================
logging.basicConfig(
    level=logging.INFO,
    format='[%(asctime)s] %(levelname)-8s: %(message)s',
    datefmt='%H:%M:%S'
)

def convert_wham_json_to_pkl(json_path: str, pkl_path: str) -> None:
    """
    Parses a JSON serialized list containing sequential frame data from the
    iOS inference pipeline and aggregates the kinematic parameters into
    contiguous NumPy tensors. The resulting data structures are then serialized
    via the Pickle protocol for downstream academic/research utilization.

    Args:
        json_path (str): The absolute or relative path to the input JSON file.
        pkl_path (str): The destination path for the serialized Pickle file.
    """
    if not os.path.exists(json_path):
        logging.error(f"FileNotFoundError: The target trajectory file '{json_path}' could not be located in the current working directory.")
        return

    logging.info(f"Initializing JSON deserialization pipeline for: {json_path}")
    try:
        with open(json_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        logging.info(f"Successfully allocated {len(data)} temporal frames into memory.")
    except json.JSONDecodeError:
        logging.error("JSONDecodeError: Malformed JSON structure detected. This typically indicates an interrupted write operation or memory corruption during the iOS inference phase.")
        return

    # Pre-allocate dynamic arrays for kinematic parameter extraction
    frames, poses, roots, keypoints = [], [], [], []

    logging.info("Extracting spatial-temporal features and aggregating into sequential buffers...")
    for idx, frame_data in enumerate(data):
        try:
            frames.append(frame_data['frame'])
            poses.append(frame_data['pose_6d'])
            roots.append(frame_data['root_orient'])
            keypoints.append(frame_data['keypoints_3d'])
        except KeyError as e:
            # Mitigates pipeline failure by gracefully handling incomplete frame outputs
            # which may occur due to asynchronous camera drops or tracking anomalies.
            logging.warning(f"Data Integrity Warning: Missing temporal key {e} at frame index {idx}. Frame omitted to preserve tensor contiguity.")
            continue

    # ==========================================================================
    # TENSOR CASTING AND OPTIMIZATION
    # Critical step: Downcasting default 64-bit Python floats to 32-bit (FP32).
    # This aligns with standard PyTorch precision limits, effectively halving
    # the memory footprint without degrading the kinematic representation.
    # ==========================================================================
    logging.info("Downcasting kinematic arrays to 32-bit floating-point tensors...")
    output_dict = {
        'frame': np.array(frames, dtype=np.int32),
        'pose_6d': np.array(poses, dtype=np.float32),
        'root_orient': np.array(roots, dtype=np.float32),
        'keypoints_3d': np.array(keypoints, dtype=np.float32)
    }

    # Output tensor dimensionalities for pipeline validation
    logging.info(f"Dimensionality of 'pose_6d':      {output_dict['pose_6d'].shape}")      # Expected: (N, 144)
    logging.info(f"Dimensionality of 'root_orient':  {output_dict['root_orient'].shape}")  # Expected: (N, 6)
    logging.info(f"Dimensionality of 'keypoints_3d': {output_dict['keypoints_3d'].shape}") # Expected: (N, 51)

    # ==========================================================================
    # BINARY SERIALIZATION
    # ==========================================================================
    logging.info(f"Executing binary serialization to destination: {pkl_path}")
    try:
        with open(pkl_path, 'wb') as f:
            # Utilizing HIGHEST_PROTOCOL for optimal I/O throughput and minimal footprint.
            pickle.dump(output_dict, f, protocol=pickle.HIGHEST_PROTOCOL)
        logging.info("Serialization complete. The kinematic payload is ready for downstream processing.")
    except Exception as e:
        logging.error(f"IOError: Serialization protocol failed. Verify storage quotas and write permissions. System traceback: {e}")

if __name__ == "__main__":
    # Thay đổi file name ở đây nếu cần
    input_file = 'Offline_681A1_wham_output.json'
    output_file = input_file.replace('.json', '.pkl')

    convert_wham_json_to_pkl(input_file, output_file)
