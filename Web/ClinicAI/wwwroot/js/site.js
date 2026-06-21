// ClinicAI — Site JavaScript
// Handles: Dark/Light theme toggle, nav scroll effect, scroll reveal, animated counters

(function () {
    'use strict';

    /* ─────────────────────────────────────────
       1. THEME MANAGEMENT
    ───────────────────────────────────────── */
    const THEME_KEY = 'clinicai-theme';
    const html = document.documentElement;

    function getStoredTheme() {
        return localStorage.getItem(THEME_KEY) || 'dark';
    }

    function applyTheme(theme) {
        html.setAttribute('data-theme', theme);
        localStorage.setItem(THEME_KEY, theme);
        updateThemeToggleIcon(theme);
    }

    function updateThemeToggleIcon(theme) {
        const icon = document.getElementById('themeIcon');
        if (!icon) return;
        if (theme === 'dark') {
            icon.classList.remove('fa-moon');
            icon.classList.add('fa-sun');
            icon.closest('button').title = 'Switch to Light Mode';
        } else {
            icon.classList.remove('fa-sun');
            icon.classList.add('fa-moon');
            icon.closest('button').title = 'Switch to Dark Mode';
        }
    }

    function toggleTheme() {
        const current = html.getAttribute('data-theme') || 'dark';
        applyTheme(current === 'dark' ? 'light' : 'dark');
    }

    // Apply on load
    document.addEventListener('DOMContentLoaded', function () {
        applyTheme(getStoredTheme());

        const toggleBtn = document.getElementById('themeToggleBtn');
        if (toggleBtn) {
            toggleBtn.addEventListener('click', toggleTheme);
        }
    });

    /* ─────────────────────────────────────────
       2. NAVBAR SCROLL EFFECT
    ───────────────────────────────────────── */
    document.addEventListener('DOMContentLoaded', function () {
        const navbar = document.querySelector('.clinicai-navbar');
        if (!navbar) return;

        function onScroll() {
            if (window.scrollY > 30) {
                navbar.classList.add('scrolled');
            } else {
                navbar.classList.remove('scrolled');
            }
        }

        window.addEventListener('scroll', onScroll, { passive: true });
        onScroll(); // run once
    });

    /* ─────────────────────────────────────────
       3. SCROLL REVEAL ANIMATION
    ───────────────────────────────────────── */
    document.addEventListener('DOMContentLoaded', function () {
        const reveals = document.querySelectorAll('.reveal');
        if (!reveals.length) return;

        const observer = new IntersectionObserver(function (entries) {
            entries.forEach(function (entry) {
                if (entry.isIntersecting) {
                    entry.target.classList.add('visible');
                    observer.unobserve(entry.target);
                }
            });
        }, { threshold: 0.12, rootMargin: '0px 0px -40px 0px' });

        reveals.forEach(function (el) { observer.observe(el); });
    });

    /* ─────────────────────────────────────────
       4. ANIMATED COUNTERS
    ───────────────────────────────────────── */
    document.addEventListener('DOMContentLoaded', function () {
        const counters = document.querySelectorAll('[data-count]');
        if (!counters.length) return;

        function easeOut(t) { return 1 - Math.pow(1 - t, 3); }

        function animateCounter(el) {
            const target = parseFloat(el.getAttribute('data-count'));
            const suffix = el.getAttribute('data-suffix') || '';
            const prefix = el.getAttribute('data-prefix') || '';
            const duration = 1800;
            const start = performance.now();
            const isFloat = String(target).includes('.');

            function step(now) {
                const elapsed = now - start;
                const progress = Math.min(elapsed / duration, 1);
                const value = target * easeOut(progress);
                el.textContent = prefix + (isFloat ? value.toFixed(1) : Math.floor(value).toLocaleString()) + suffix;
                if (progress < 1) requestAnimationFrame(step);
                else el.textContent = prefix + (isFloat ? target.toFixed(1) : target.toLocaleString()) + suffix;
            }
            requestAnimationFrame(step);
        }

        const observer = new IntersectionObserver(function (entries) {
            entries.forEach(function (entry) {
                if (entry.isIntersecting) {
                    animateCounter(entry.target);
                    observer.unobserve(entry.target);
                }
            });
        }, { threshold: 0.5 });

        counters.forEach(function (el) { observer.observe(el); });
    });

    /* ─────────────────────────────────────────
       5. NAVBAR ACTIVE LINK HIGHLIGHT
    ───────────────────────────────────────── */
    document.addEventListener('DOMContentLoaded', function () {
        const links = document.querySelectorAll('.clinicai-navbar .nav-link');
        const currentPath = window.location.pathname.toLowerCase();

        links.forEach(function (link) {
            const href = link.getAttribute('href');
            if (!href) return;
            const path = href.toLowerCase();
            if (path !== '/' && currentPath.startsWith(path)) {
                link.classList.add('active');
            } else if (path === '/' && currentPath === '/') {
                link.classList.add('active');
            }
        });
    });

    /* ─────────────────────────────────────────
       6. BAR CHART ANIMATION STAGGER (Mock)
    ───────────────────────────────────────── */
    document.addEventListener('DOMContentLoaded', function () {
        const bars = document.querySelectorAll('.mock-bar');
        bars.forEach(function (bar, i) {
            bar.style.animationDelay = (i * 0.07) + 's';
        });
    });

})();
