from gym import Env

import numpy as np
from psutil import AccessDenied

import ur_env.remote
from ur_env.base import Environment, Timestep
from ur_env.remote import RemoteEnvServer, RemoteEnvClient

import sys
sys.path.append('/home/jupyter/c2farm/ARM/arm/')

import utils
from scipy.spatial.transform import Rotation as R

from yarr.envs.env import Env
from yarr.utils.transition import Transition
from yarr.utils.observation_type import ObservationElement

from os.path import join, exists
from os import listdir
import pickle
from natsort import natsorted



class EnvClient(Env):
    def __init__(self,
                 #host = "10.46.3.232",
                 host = "4.tcp.eu.ngrok.io",
                 port = 10160
                 ):
        super(EnvClient).__init__()
        self.host = host
        self.port = port
        self.address = (host, port)

        self.reward_scale = 100

        self._active_task_id = 0
        self.episode_index = 0
        self.episode_lenth = 10

        self.client = RemoteEnvClient(self.address)
        self._dataset_root = '/home/jupyter/c2farm/demos/myDemoKinect'
        
        self.camera_intrinsics = np.array([[505.07427979, 0, 326.2756958],
                                           [0, 505.21359253, 338.62103271],
                                           [0, 0, 1]], dtype=np.float32)


        self.Rot_M = np.array([
            [-0.56396701,  0.24796995, -0.78768783],
            [ 0.42248543,  0.90620631, -0.01720975],
            [ 0.70954019, -0.34249237, -0.61583415]], dtype=np.float32)





        self.tvec = np.array([[ 0.0932756,  -0.168814,   -1.01014076]], dtype=np.float32)
        self.camera_extrinsics = np.array([
            [-0.56396701,  0.24796995, -0.78768783, 0.0932756],
            [ 0.42248543,  0.90620631, -0.01720975, -0.168814],
            [ 0.70954019, -0.34249237, -0.61583415, -1.01014076],
                                           [0, 0, 0, 1]], dtype=np.float32)

    @property
    def observation_space(self):
        print("obs_space")
        return self.client.observation_space

    @property
    def action_space(self):
        print("act_space")
        return self.client.action_space
    
    @property
    def env(self):
        print("ENV")
        return self

    def shutdown(self):
        print("SHUTDOWN")
        # self.client.close()
        
    def reset(self):
        print("RESET")
        return self.client.reset()

    def step(self, action):
        act = action.action.copy()
        act = np.concatenate([act[:3], R.from_quat(act[3:-1]).as_rotvec(), [act[-1]]])
        print('STEP:  ', act)
        return self.client.step(act)
    
    def launch(self):
        print("LAUNCH")
        pass

    def action_shape(self):
        print("ACT_SHPE")
        return (7,)

    def extract_obs(self, obs, t=None, prev_action=None):
        print("EXTRACT_OBS")
        low_dim_names = ['arm/ActualTCPPose', 
                         'gripper/pose',
                         'gripper/is_closed', 
                         'gripper/object_detected', 
                        ]

        TCP_quat = obs['arm/ActualTCPPose'].copy()
        TCP_quat = np.concatenate([TCP_quat[0:3], R.from_rotvec(TCP_quat[3:]).as_quat()])
        
        low_dim_state = np.concatenate([TCP_quat if k=='arm/ActualTCPPose' else obs[k] for k in low_dim_names])
        

        ext_obs = {
                    'low_dim_state': np.array(low_dim_state, dtype=np.float32),
                    'gripper_pose': np.array(np.concatenate([TCP_quat, obs['gripper/is_closed']]), dtype=np.float32),
                    'front_rgb': np.array(obs['kinect/image'][::6, ::10, :][:120, :128, :].transpose(2, 0, 1), dtype=np.uint8),
                    'front_point_cloud': np.array(np.matmul((obs['kinect/point_cloud'][::6, ::10, :][:120, :128, :] + self.tvec), self.Rot_M).transpose(2, 0, 1), dtype=np.float32),
                    'front_camera_intrinsics': self.camera_intrinsics,
                    'front_camera_extrinsics': self.camera_extrinsics,
                  }
        return ext_obs

    @property
    def observation_elements(self):
        print("OBS_ELEMS")
        elements = []
        elements.append(ObservationElement('low_dim_state', (10, ), np.float32))
        
        # IMPORTANT!!!
        self.low_dim_state_len = 10
        elements.append(ObservationElement('gripper_pose', (8, ), np.float32))
        elements.append(ObservationElement('front_rgb', (3, 120, 128), np.uint8))
        elements.append(ObservationElement('front_point_cloud', (3, 120, 128), np.float32))
        elements.append(ObservationElement('front_camera_intrinsics', (3, 3), np.float32))
        elements.append(ObservationElement('front_camera_extrinsics', (4, 4), np.float32))

        return elements



    def get_demos(self, task_name: str, amount: int,
                  variation_number=0,
                  image_paths=False,
                  random_selection: bool = True,
                  from_episode_number: int = 0):
        print("GET_DEMOS")
        if self._dataset_root is None or len(self._dataset_root) == 0:
            raise RuntimeError(
                "Can't ask for a stored demo when no dataset root provided.")

        task_path = join(self._dataset_root, task_name)
        
        

        examples_path = join(task_path, 'episodes')
        examples = listdir(examples_path)



        if random_selection:
            selected_examples = np.random.choice(examples, amount, replace=False)
        else:
            selected_examples = natsorted(examples)[from_episode_number:from_episode_number+amount]

        demos = []
           
        for example in selected_examples:
            path = join(examples_path, example)
            obs_path = join(path, 'obs.pkl')
            
            with open(obs_path, 'rb') as f:
                obs = pickle.load(f)
            demos.append(obs)

        return demos

