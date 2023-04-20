FROM ubuntu:20.04

ENV DEBIAN_FRONTEND noninteractive
ENV NVIDIA_VISIBLE_DEVICES all
ENV NVIDIA_DRIVER_CAPABILITIES compute,utility,display,graphics,video

# Install base utilities
RUN apt-get update && apt-get install -y \
 git \
 gcc \
 vim \
 mc \
 xvfb \
 xserver-xorg-core \
 apt-utils \
 libxcb-randr0-dev \ 
 libxrender-dev \
 libxkbcommon-dev \
 libxkbcommon-x11-0 \
 libavcodec-dev \
 libavformat-dev 

# DataSphere
RUN useradd -ms /bin/bash --uid 1000 jupyter\
 && apt update\
 && apt install -y python3.9-dev python3.9-distutils gnupg wget software-properties-common curl\
 && ln -s /usr/bin/python3.9 /usr/local/bin/python3\
 && curl https://bootstrap.pypa.io/get-pip.py | python3
 
ENV LD_LIBRARY_PATH /usr/local/cuda-11.2/lib64:/usr/local/nvidia/lib:/usr/local/nvidia/lib64:/usr/local/cuda/lib64:/usr/local/cuda/extras/CUPTI/lib64

# Install miniconda
ENV CONDA_DIR /opt/conda
RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda.sh\
 && /bin/bash ~/miniconda.sh -b -p /opt/conda\
 && rm -f Miniconda3-latest-Linux-x86_64.sh

# Put conda in path so we can use conda activate
ENV PATH=$CONDA_DIR/bin:$PATH

# Create the environment:
RUN mkdir -p /home/jupyter/c2farm
WORKDIR /home/jupyter/c2farm
RUN conda create --name c2farm-conda python=3.9

# Make RUN commands use the new environment:
SHELL ["conda", "run", "-n", "c2farm-conda", "/bin/bash", "-c"]
RUN conda install --v pytorch torchvision torchaudio pytorch-cuda=11.7 -c pytorch -c nvidia

# YARR RL framework for PyTorch
RUN git clone https://github.com/stepjam/YARR.git
RUN pip install ./YARR
RUN pip install chardet

# CopelliaSim
RUN wget https://www.coppeliarobotics.com/files/CoppeliaSim_Edu_V4_1_0_Ubuntu20_04.tar.xz
RUN tar -xf CoppeliaSim_Edu_V4_1_0_Ubuntu20_04.tar.xz
RUN rm CoppeliaSim_Edu_V4_1_0_Ubuntu20_04.tar.xz

# Add correct paths to the .bashrc
ENV COPPELIASIM_ROOT=/home/jupyter/c2farm/CoppeliaSim_Edu_V4_1_0_Ubuntu20_04
ENV LD_LIBRARY_PATH=/home/jupyter/c2farm/CoppeliaSim_Edu_V4_1_0_Ubuntu20_04
ENV QT_QPA_PLATFORM_PLUGIN_PATH=/home/jupyter/c2farm/CoppeliaSim_Edu_V4_1_0_Ubuntu20_04

# Install PyRep, toolkit for robot learning research
RUN git clone https://github.com/stepjam/PyRep.git
RUN pip install -r ./PyRep/requirements.txt
RUN pip install ./PyRep

# Install RLBench
RUN git clone https://github.com/stepjam/RLBench.git
RUN pip install -r ./RLBench/requirements.txt
RUN pip install ./RLBench

# Install VirtualGL
RUN wget --no-check-certificate https://sourceforge.net/projects/virtualgl/files/2.5.2/virtualgl_2.5.2_amd64.deb -O /home/jupyter/c2farm/virtualgl_2.5.2_amd64.deb
RUN dpkg -i virtualgl*.deb
RUN rm virtualgl*.deb

# Install Attention-driven Robotic Manipulation (ARM)
RUN git clone https://github.com/stepjam/ARM.git
RUN pip install -r ./ARM/requirements.txt

# Install GPU monitoring (nvitop command)
RUN pip3 install --upgrade nvitop
RUN pip3 install git+https://github.com/XuehaiPan/nvitop.git#egg=nvitop

RUN conda install gym -c conda-forge 

# The format of the display variable is [host]:<display>[.screen]
ENV DISPLAY=:0.0

RUN pip install ruamel.yaml plotly matplotlib
RUN git clone https://github.com/RQC-Robotics/ur5-env.git
RUN git --git-dir=./ur5-env/.git --work-tree=./ur5-env/ checkout 1b8b8e62328e75063eefc6a6ed1708e4c5268977
RUN pip install ./ur5-env

# Copying the files
COPY *.py ./
COPY *.sh ./
COPY ./rqc_c2farm_files/launch.py                                               ./ARM/
COPY ./rqc_c2farm_files/env_client.py ./rqc_c2farm_files/demo_loading_utils.py  ./ARM/arm/
COPY ./rqc_c2farm_files/launch_utils.py                                         ./ARM/arm/c2farm/
COPY ./rqc_c2farm_files/conf/                                                   ./ARM/conf/

RUN mkdir -p ./demos

# ENTRYPOINT ["/bin/bash"]
CMD ["/bin/bash"] 


