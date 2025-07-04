# dev
git config user.name "username"
git config user.email "email"
git clone git@github.com:alienschub/alienhub.git
cd alienhub
git remote set-url origin git@github.com:alienschub/alienhub.git
git add .
git commit -m "Force push update"
git push --force origin main
git branch
ssh-keygen -t ed25519 -C "alienschub@example.com" -f ~/.ssh/id_ed25519_alienschub
cat ~/.ssh/id_ed25519_alienschub.pub
ssh-add -l
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519_alienschub
git remote -v
ssh -T git@github.com

# alienhub
# Soft reset ke awal (hapus semua history)
git checkout --orphan temp_branch
git add .
git commit -m "Initial commit"

# Hapus branch lama dan rename
git branch -D main
git branch -M main

# Force push ke remote
git push -f origin main