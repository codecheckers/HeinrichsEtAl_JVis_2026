from matplotlib import pyplot as plt    
import os


def save_figure(fig_dir, fig_name, fig):
    """Save figure to specified directory with given name."""
    if not os.path.exists(fig_dir):
        os.makedirs(fig_dir)
        print(f"Created directory: {fig_dir}")
    fig_path = os.path.join(fig_dir, fig_name)
    fig.savefig(fig_path, dpi=300)
    print(f"Figure saved to: {os.path.abspath(fig_path)}")
    plt.close(fig)