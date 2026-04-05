import './App.css'
import teamMembers from './data/team.json'

const steps = [
  {
    id: '01',
    title: 'Choose a skill',
    description:
      'Start by picking the skill you want to grow so Lattice can focus your journey.',
    marker: 'spark',
  },
  {
    id: '02',
    title: 'Make a plan',
    description:
      'Build a simple roadmap with guided tasks, habits, and milestones that fit your pace.',
    marker: 'map',
  },
  {
    id: '03',
    title: 'Track your growth',
    description:
      'See your progress over time and keep momentum with a clear record of what is working.',
    marker: 'pulse',
  },
]

const storeBadges = {
  googlePlay: {
    src: '/badges/google-download-white.svg',
    fileName: 'google-download-white.svg',
    alt: 'Google Play download badge',
  },
  appStore: {
    src: '/badges/apple-download-white.svg',
    fileName: 'apple-download-white.svg',
    alt: 'App Store download badge',
  },
}

const brandLogo = {
  src: '/LOGO.png',
  fileName: 'LOGO.png',
  alt: 'Lattice logo',
}

function StoreBadge({ badge }) {
  return (
    <a
      className="store-badge store-badge--image"
      href="/"
      onClick={(event) => event.preventDefault()}
    >
      {badge.src ? (
        <img src={badge.src} alt={badge.alt} />
      ) : (
        <span className="store-badge__placeholder">
          Drop in <code>{badge.fileName}</code>
        </span>
      )}
    </a>
  )
}

function BrandLogo() {
  return (
    <span className="brand-logo" aria-hidden="true">
      {brandLogo.src ? (
        <img src={brandLogo.src} alt={brandLogo.alt} />
      ) : (
        <span className="brand-logo__placeholder">{brandLogo.fileName}</span>
      )}
    </span>
  )
}

function SocialIcon({ type }) {
  if (type === 'gravatar') {
    return <img src="/gravatar.png" alt="" />
  }

  if (type === 'linkedin') {
    return (
      <svg viewBox="0 0 24 24" aria-hidden="true">
        <path d="M6.8 8.6A1.8 1.8 0 1 1 6.8 5a1.8 1.8 0 0 1 0 3.6ZM5.2 10h3.1v8.8H5.2V10Zm4.8 0h3v1.2h.1c.4-.8 1.5-1.5 3-1.5 3.2 0 3.8 2 3.8 4.7v4.4h-3.1V15c0-.9 0-2.1-1.4-2.1s-1.7 1-1.7 2v4h-3.1V10Z" />
      </svg>
    )
  }

  if (type === 'github') {
    return (
      <svg viewBox="0 0 24 24" aria-hidden="true">
        <path d="M12 3.2a8.8 8.8 0 0 0-2.8 17.2c.4.1.6-.2.6-.5v-1.8c-2.4.5-2.9-1-2.9-1-.4-.9-1-1.2-1-1.2-.8-.5.1-.5.1-.5.9.1 1.4.9 1.4.9.8 1.3 2.1.9 2.6.7.1-.6.3-.9.5-1.2-1.9-.2-3.9-1-3.9-4.2 0-.9.3-1.7.9-2.3-.1-.2-.4-1.1.1-2.2 0 0 .8-.2 2.5.9a8.5 8.5 0 0 1 4.6 0c1.7-1.1 2.5-.9 2.5-.9.5 1.1.2 2 .1 2.2.6.6.9 1.4.9 2.3 0 3.2-2 3.9-3.9 4.2.3.3.6.8.6 1.7v2.5c0 .3.2.6.6.5A8.8 8.8 0 0 0 12 3.2Z" />
      </svg>
    )
  }
  return null
}

function TeamAvatar({ member }) {
  const label = `${member.name} profile`
  const hasPhoto = Boolean(member.photo)
  const photoSrc = hasPhoto ? `/team/${member.photo}` : null
  const socialLinks = [
    { type: 'gravatar', href: member.gravatar, label: `${member.name} on Gravatar` },
    { type: 'linkedin', href: member.linkedin, label: `${member.name} on LinkedIn` },
    { type: 'github', href: member.github, label: `${member.name} on GitHub` },
  ].filter((link) => link.href)

  return (
    <div className="team-avatar-shell">
      <div className="team-avatar-links">
        {socialLinks.map((link, index) => (
          <a
            className={`team-avatar-link team-avatar-link--${index + 1}`}
            href={link.href}
            key={link.type}
            target="_blank"
            rel="noreferrer"
            aria-label={link.label}
          >
            <SocialIcon type={link.type} />
          </a>
        ))}
      </div>

      <div className={`avatar avatar--${member.tone}`} aria-label={label}>
        {hasPhoto ? (
          <img src={photoSrc} alt={label} />
        ) : (
          <span>{member.fallbackLetter || member.name[0]}</span>
        )}
      </div>
    </div>
  )
}

function StepIcon({ marker }) {
  if (marker === 'spark') {
    return (
      <svg viewBox="0 0 24 24" aria-hidden="true">
        <path d="M12 2.5 14.8 8l5.7.8-4.1 4 1 5.7L12 15.7 6.6 18.5l1-5.7-4.1-4 5.7-.8Z" />
      </svg>
    )
  }

  if (marker === 'map') {
    return (
      <svg viewBox="0 0 24 24" aria-hidden="true">
        <path d="M3.5 6.5c0-.5.3-.9.8-1.1l4.7-1.6c.3-.1.7-.1 1 .1l4.1 1.8 4.9-1.7a1 1 0 0 1 1.3 1v12.4c0 .5-.3.9-.8 1.1l-4.7 1.6c-.3.1-.7.1-1-.1l-4.1-1.8-4.9 1.7a1 1 0 0 1-1.3-1Zm6.5-.1v11.3l4 1.7V8.1Zm6 .1v11.3l3-1V5.5Z" />
      </svg>
    )
  }

  return (
    <svg viewBox="0 0 24 24" aria-hidden="true">
      <path d="M12 4a8 8 0 1 0 8 8h-2.3a5.7 5.7 0 1 1-1.6-4l-2.8 2.8H20V4.4l-2.2 2.2A7.9 7.9 0 0 0 12 4Z" />
      <path d="M12 8.3a.9.9 0 0 1 .9.9v2.2l2 1.1a.9.9 0 0 1-.9 1.5l-2.5-1.4a.9.9 0 0 1-.4-.8V9.2a.9.9 0 0 1 .9-.9Z" />
    </svg>
  )
}

function App() {
  return (
    <main className="landing-page">
      <header className="topbar">
        <button className="menu-button" type="button" aria-label="Open menu">
          <span />
          <span />
          <span />
        </button>

        <a className="brand" href="#hero" aria-label="Lattice home">
          <BrandLogo />
        </a>
      </header>

      <section className="hero-section" id="hero">
      <div className="starfield" />

        <div className="hero-copy">
          <p className="eyebrow">Skill development, structured for momentum</p>
          <h1>Lets progress through your skill development. Download Lattice Today!</h1>

          <div className="store-buttons">
            <StoreBadge badge={storeBadges.googlePlay} />

            <span className="store-divider">OR</span>

            <StoreBadge badge={storeBadges.appStore} />
          </div>
        </div>

        <div className="section-divider" />

        <section className="steps-section" aria-labelledby="steps-heading">
          <h2 id="steps-heading">First steps</h2>

          <div className="steps-layout">
            <div className="steps-pathway" aria-label="Three onboarding steps">
              {steps.map((step, index) => (
                <article
                  className={`step-card step-card--${index + 1}`}
                  key={step.id}
                >
                  <div className={`step-card__marker step-card__marker--${step.marker}`}>
                    <StepIcon marker={step.marker} />
                  </div>

                  <div className="step-card__body">
                    <p className="step-card__eyebrow">Step {index + 1}</p>
                    <h3>{step.title}</h3>
                    <p>{step.description}</p>
                  </div>
                </article>
              ))}
            </div>

            <div className="feature-stack" aria-hidden="true">
              <img src="/PlanCards.png?v=2" alt="" />
            </div>
          </div>
        </section>

        <div className="section-divider" />

        <section className="team-section" aria-labelledby="team-heading">
          <h2 id="team-heading">Meet the team behind LATTICE!</h2>

          <div className="team-grid">
            {teamMembers.map((member) => (
              <article className="team-member" key={member.name}>
                <TeamAvatar member={member} />
                <h3>{member.name}</h3>
                <p>{member.school}</p>
              </article>
            ))}
          </div>
        </section>
      </section>
    </main>
  )
}

export default App
