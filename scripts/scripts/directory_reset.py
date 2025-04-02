import os
import shutil

def clean_directory(directory):
    keep_files = {"jobscript", "INCAR", "POSCAR", "KPOINTS", "POTCAR"}
    
    for item in os.listdir(directory):
        item_path = os.path.join(directory, item)
        
        # Skip subdirectories
        if os.path.isdir(item_path):
            continue
        
        # Delete files not in keep_files
        if item not in keep_files:
            os.remove(item_path)
            print(f"Deleted: {item_path}")

if __name__ == "__main__":
    dir_path = input("Enter the directory path: ")
    if os.path.exists(dir_path) and os.path.isdir(dir_path):
        clean_directory(dir_path)
        print("Cleanup complete.")
    else:
        print("Invalid directory path.")

