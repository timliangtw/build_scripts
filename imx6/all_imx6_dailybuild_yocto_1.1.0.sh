#!/bin/bash

DATE=`date +%F`

echo "[ADV] STORAGE_PATH = ${STORAGE_PATH}"
echo "[ADV] SVN_URL = ${SVN_URL}"
echo "[ADV] BUILDALL_DIR = ${BUILDALL_DIR}"
echo "[ADV] DEPLOY_IMAGE_NAME = ${DEPLOY_IMAGE_NAME}"
echo "[ADV] RELEASE_VERSION = ${RELEASE_VERSION}"
echo "[ADV] MACHINE_LIST = ${MACHINE_LIST}"

ROOT_DIR="imx6LB${RELEASE_VERSION}"_"$DATE"
OUTPUT_DIR="$STORAGE_PATH/$DATE"

CURR_PATH="$PWD"

# Make storage folder
if [ -e $OUTPUT_DIR ] ; then
    echo "[ADV] $OUTPUT_DIR had already been created"
else
    echo "[ADV] mkdir $OUTPUT_DIR"
    mkdir $OUTPUT_DIR
fi

# ===========
#  Functions
# ===========
function generate_md5()
{
    FILENAME=$1

    if [ -e $FILENAME ]; then
        MD5_SUM=`md5sum -b $FILENAME | cut -d ' ' -f 1`
        echo $MD5_SUM > $FILENAME.md5
    fi
}

function save_temp_log()
{
    LOG_PATH="$CURR_PATH/$ROOT_DIR/$BUILDALL_DIR"
    cd $LOG_PATH

    echo "[ADV] mkdir $LOG_DIR"
    mkdir $LOG_DIR

    # Backup conf, run script & log file
    cp -a conf $LOG_DIR
    find tmp/work -name "log.*_*" -o -name "run.*_*" | xargs -i cp -a --parents {} $LOG_DIR

    echo "[ADV] creating ${LOG_DIR}.tgz ..."
    tar czf $LOG_DIR.tgz $LOG_DIR
    generate_md5 $LOG_DIR.tgz

    mv -f $LOG_DIR.tgz $OUTPUT_DIR
    mv -f $LOG_DIR.tgz.md5 $OUTPUT_DIR

    # Remove all temp logs
    rm -rf $LOG_DIR
    find . -name "temp" | xargs rm -rf
}

function building()
{
    echo "[ADV] building $1 $2..."
    LOG_DIR="LI${RELEASE_VERSION}"_"$NEW_MACHINE"_"$DATE"_log

    if [ "x" != "x$2" ]; then
        bitbake $1 -c $2 -f

    else
        bitbake $1
    fi

    [ "$?" -ne 0 ] && echo "[ADV] Build failure! Check details in ${LOG_DIR}.tgz" && save_temp_log && rm -rf $CURR_PATH/$ROOT_DIR && exit 1
}

function build_yocto_images()
{
    cd $CURR_PATH/$ROOT_DIR

    # set_environment
    echo "[ADV] change $NEW_MACHINE"
    sed -i "s/MACHINE ??=.*/MACHINE ??= '$NEW_MACHINE'/g" $BUILDALL_DIR/conf/local.conf

    EULA=1 source setup-environment $BUILDALL_DIR

    # Re-build U-Boot & kernel
    building u-boot-imx cleansstate
    building u-boot-imx

    building linux-imx cleansstate
    building linux-imx

    # Clean configs for qt5
    if [ "$DEPLOY_IMAGE_NAME" == "fsl-image-qt5" ]; then
        echo "[ADV] build_yocto_image: qt package cleansstate!"
        building qtbase-native cleansstate
        building qtbase cleansstate
        building qtdeclarative cleansstate
        building qtxmlpatterns cleansstate
        building qtwayland cleansstate
        building qtmultimedia cleansstate
        building qt3d cleansstate
        building qtgraphicaleffects cleansstate
        building qt5nmapcarousedemo cleansstate
        building qt5everywheredemo cleansstate
        building quitbattery cleansstate
        building qtsmarthome cleansstate
        building qtsensors cleansstate
        building cinematicexperience cleansstate
        building qt5nmapper cleansstate
        building quitindicators cleansstate
        building qtlocation cleansstate
        building qtwebkit cleansstate
        building qtwebkit-examples cleansstate
    fi

    # Build full image
    building $DEPLOY_IMAGE_NAME
}

function prepare_images()
{
    cd $CURR_PATH

    IMAGE_DIR="LI${RELEASE_VERSION}"_"$NEW_MACHINE"_"$DATE"
    echo "[ADV] mkdir $IMAGE_DIR"
    mkdir $IMAGE_DIR

    # Copy image files to image directory
    DEPLOY_IMAGE_PATH="$CURR_PATH/$ROOT_DIR/$BUILDALL_DIR/tmp/deploy/images/${NEW_MACHINE}"

    # Normal image
    FILE_NAME=${DEPLOY_IMAGE_NAME}"-"${NEW_MACHINE}"*.rootfs.sdcard"
    mv $DEPLOY_IMAGE_PATH/$FILE_NAME $IMAGE_DIR

    echo "[ADV] creating ${IMAGE_DIR}.img.gz ..."
    gzip -c9 $IMAGE_DIR/$FILE_NAME > $IMAGE_DIR.img.gz
    generate_md5 $IMAGE_DIR.img.gz
    rm $IMAGE_DIR/$FILE_NAME

    # Eng image
    FILE_NAME=${DEPLOY_IMAGE_NAME}"-"${NEW_MACHINE}"*.rootfs.eng.sdcard"
    mv $DEPLOY_IMAGE_PATH/$FILE_NAME $IMAGE_DIR

    echo "[ADV] creating ${IMAGE_DIR}_eng.img.gz ..."
    gzip -c9 $IMAGE_DIR/$FILE_NAME > ${IMAGE_DIR}_eng.img.gz
    generate_md5 ${IMAGE_DIR}_eng.img.gz
    rm $IMAGE_DIR/$FILE_NAME

    # U-Boot & SPL
    echo "[ADV] creating ${IMAGE_DIR}.tgz for u-boot & SPL images ..."
    mv $DEPLOY_IMAGE_PATH/SPL* $IMAGE_DIR
    mv $DEPLOY_IMAGE_PATH/u-boot* $IMAGE_DIR
    tar czf ${IMAGE_DIR}_spl.tgz $IMAGE_DIR
    generate_md5 ${IMAGE_DIR}_spl.tgz

    rm -rf $IMAGE_DIR
}

function copy_image_to_storage()
{
    echo "[ADV] copy images to $OUTPUT_DIR"

    mv -f ${IMAGE_DIR}.img.gz $OUTPUT_DIR
    mv -f ${IMAGE_DIR}_eng.img.gz $OUTPUT_DIR
    mv -f ${IMAGE_DIR}_spl.tgz $OUTPUT_DIR

    mv -f *.md5 $OUTPUT_DIR
}

# ================
#  Main procedure 
# ================
echo "[ADV] get yocto source code"
svn export $SVN_URL $ROOT_DIR > /dev/null

echo "[ADV] set environment"
cd $ROOT_DIR

# Link downloads directory from backup
if [ -e $CURR_PATH/downloads ] ; then
    echo "[ADV] link downloads directory"
    ln -s $CURR_PATH/downloads downloads
fi

EULA=1 source fsl-setup-release.sh -b $BUILDALL_DIR -e x11

echo "[ADV] build images"
for NEW_MACHINE in $MACHINE_LIST
do
    build_yocto_images
    prepare_images
    copy_image_to_storage
    save_temp_log
done

# Copy downloads to backup
if [ ! -e $CURR_PATH/downloads ] ; then
    echo "[ADV] backup 'downloads' directory"
    cp -a $CURR_PATH/$ROOT_DIR/downloads $CURR_PATH
fi

cd $CURR_PATH
rm -rf $ROOT_DIR

echo "[ADV] build script done!"

