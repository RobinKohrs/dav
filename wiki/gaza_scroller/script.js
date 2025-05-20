<script>
// Widget JavaScript
    const toggleButton = document.getElementById('toggleScrollButton');
    const outerImageContainer = document.getElementById('outerImageContainer');
    const imageContentWrapper = document.getElementById('imageContentWrapper');
    const mainImage = document.getElementById('mainImage');
    const scrollProgressBar = document.getElementById('scrollProgressBar');
    const customScrollDownBtn = document.getElementById('customScrollDownBtn');
    const topFadeOverlay = document.getElementById('topFadeOverlay');
    const bottomFadeOverlay = document.getElementById('bottomFadeOverlay');

    let isImageScrollActive = true;

    function updateStickyElementsVisibility() {
        if (!outerImageContainer || !imageContentWrapper) return;

        if (!isImageScrollActive) {
            if (customScrollDownBtn) customScrollDownBtn.style.display = 'none';
            if (topFadeOverlay) topFadeOverlay.style.display = 'none';
            if (bottomFadeOverlay) bottomFadeOverlay.style.display = 'none';
            return;
        }

        const scrollHeight = imageContentWrapper.scrollHeight;
        const scrollTop = imageContentWrapper.scrollTop;
        const clientHeight = imageContentWrapper.clientHeight;
        const canScroll = scrollHeight > clientHeight;

        if (topFadeOverlay) {
            topFadeOverlay.style.display = canScroll ? 'block' : 'none';
        }
        if (bottomFadeOverlay) {
            bottomFadeOverlay.style.display = canScroll ? 'block' : 'none';
        }

        if (customScrollDownBtn) {
            if (canScroll && (scrollTop + clientHeight < scrollHeight - 5)) {
                customScrollDownBtn.style.display = 'flex';
            } else {
                customScrollDownBtn.style.display = 'none';
            }
        }
    }

    function updateScrollProgress() {
        if (!mainImage || !imageContentWrapper || !scrollProgressBar) return;

        if (!mainImage.complete || (mainImage.naturalHeight === 0 && !mainImage.src.startsWith('https://via.placeholder.com'))) {
             if (!mainImage.dataset.retrying) {
                mainImage.dataset.retrying = "true";
                requestAnimationFrame(updateScrollProgress);
            }
            return;
        }
        delete mainImage.dataset.retrying;

        const scrollTop = imageContentWrapper.scrollTop;
        const scrollHeight = imageContentWrapper.scrollHeight;
        const clientHeight = imageContentWrapper.clientHeight;

        if (scrollHeight <= clientHeight) {
            scrollProgressBar.style.height = '0%';
        } else {
            const scrollableDistance = scrollHeight - clientHeight;
            const scrollPercentage = (scrollTop / scrollableDistance) * 100;
            scrollProgressBar.style.height = `${Math.min(100, Math.max(0, scrollPercentage))}%`;
        }
        updateStickyElementsVisibility();
    }

    if (imageContentWrapper) {
        imageContentWrapper.addEventListener('scroll', () => {
            if (isImageScrollActive) {
                requestAnimationFrame(updateScrollProgress);
            }
        });
    }

    if (customScrollDownBtn) {
        customScrollDownBtn.addEventListener('click', () => {
            if (isImageScrollActive && imageContentWrapper) {
                imageContentWrapper.scrollBy({
                    top: imageContentWrapper.clientHeight * 0.75,
                    behavior: 'smooth'
                });
            }
        });
    }

    if (toggleButton) {
        toggleButton.addEventListener('click', () => {
            isImageScrollActive = !isImageScrollActive;
            document.body.classList.toggle('image-scrolling-active', isImageScrollActive);
            document.body.classList.toggle('site-scrolling-active', !isImageScrollActive);

            toggleButton.textContent = isImageScrollActive ? 'Toggle to Site Scroll' : 'Toggle to Image Scroll';

            updateScrollProgress();
        });
    }

    function initializeWidget() {
        if (!outerImageContainer || !mainImage) return;

        document.body.classList.add('image-scrolling-active');
        document.body.classList.remove('site-scrolling-active');
        if (toggleButton) toggleButton.textContent = 'Toggle to Site Scroll';

        const loadImageAndInitialize = () => {
            if (!document.body.contains(mainImage)) {
                console.warn("mainImage no longer in DOM during loadImageAndInitialize");
                return;
            }
            updateScrollProgress();
            if (outerImageContainer) { // Check again as it might be removed from DOM by other scripts
                 outerImageContainer.classList.add('loaded');
            }
        };

        if (mainImage.complete && (mainImage.naturalHeight > 0 || mainImage.src.startsWith('https://via.placeholder.com'))) {
            loadImageAndInitialize();
        } else {
            mainImage.addEventListener('load', loadImageAndInitialize, { once: true });
            mainImage.addEventListener('error', () => {
                console.warn("Image failed to load. Attempting to initialize with placeholder.");
                setTimeout(loadImageAndInitialize, 50); // Give placeholder time to load if src changed by onerror
            }, { once: true });
        }
    }

    window.addEventListener('load', () => {
        if (document.getElementById('outerImageContainer')) { // Check if the main container exists
             initializeWidget();
        } else {
            console.warn("outerImageContainer not found on window.load. Widget not initialized.");
        }
    });

    window.addEventListener('resize', () => {
        if (mainImage && (mainImage.complete || mainImage.src.startsWith('https://via.placeholder.com'))) {
            requestAnimationFrame(updateScrollProgress);
        }
    });
</script>
