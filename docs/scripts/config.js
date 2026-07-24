module.exports = {
  // Shown in the site's top bar and browser tab. Set this to your project's name.
  siteName: 'Project Documentation',

  // Role picker ("I work in...") on the Overview page. Keys are role ids; values are the
  // business-doc *categories* that role's sidebar filter keeps. "Getting Started" is always
  // kept regardless of the active role. "developer" is handled specially — it jumps straight
  // to /tech instead of filtering the business sidebar. Add one entry per audience.
  roleCategories: {
    // example: sales: ['Orders'],
    // example: operations: ['Orders', 'Billing'],
  },

  // Key business terms shown on the Overview page. Add your domain's vocabulary.
  glossary: [
    // example: { term: 'Order', definition: 'A confirmed or in-progress customer purchase.' },
  ],
};
